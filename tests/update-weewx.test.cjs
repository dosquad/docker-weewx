const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

// Exercise the actual GitHub Script body without making API writes.
const workflow = fs.readFileSync(path.join(__dirname, '../.github/workflows/update-weewx.yml'), 'utf8');
const script = workflow.split('          script: |\n')[1]
  .split('\n').map(line => line.slice(12)).join('\n');
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const run = new AsyncFunction('github', 'context', 'core', script);

async function scenario({ current = 'v5.1.0', latest = 'v5.2.0', exists = false,
  lookupStatus = 404, commitFails = false, prerelease = false, source } = {}) {
  const writes = [];
  const refs = [];
  const input = source ?? `FROM example\nARG WEEWX_RELEASE=${current}\n# preserved\n`;
  const github = { rest: {
    repos: {
      getLatestRelease: async () => ({ data: { tag_name: latest, prerelease, draft: false } }),
      getBranch: async () => ({ data: { commit: { sha: 'inspected-head' } } }),
      getContent: async args => {
        assert.equal(args.ref, 'inspected-head');
        return { data: { type: 'file', encoding: 'base64', sha: 'blob-sha',
          content: Buffer.from(input).toString('base64') } };
      },
      createOrUpdateFileContents: async args => {
        if (commitFails) throw new Error('conflict');
        assert.equal(args.sha, 'blob-sha');
        assert.equal(args.branch, 'main');
        assert.equal(Buffer.from(args.content, 'base64').toString(),
          input.replace(`ARG WEEWX_RELEASE=${current}`, `ARG WEEWX_RELEASE=${latest}`));
        writes.push(args);
        return { data: { commit: { sha: 'updated-commit' } } };
      },
    },
    git: {
      getRef: async () => {
        if (!exists) throw Object.assign(new Error('lookup failed'), { status: lookupStatus });
        return { data: { object: { sha: 'existing-release' } } };
      },
      createRef: async args => refs.push(args),
    },
  } };
  await run(github, { repo: { owner: 'example', repo: 'weewx' } }, { info() {} });
  return { writes, refs };
}

test('new releases tag the returned update commit, preserving other Dockerfile content', async () => {
  for (const latest of ['v5.2.0', 'v5.10.0', 'v6.0.0', '5.2.0']) {
    const { writes, refs } = await scenario({ latest });
    assert.equal(writes.length, 1);
    assert.equal(refs.length, 1);
    assert.equal(refs[0].sha, 'updated-commit');
    assert.equal(refs[0].ref, `refs/tags/v${latest.replace(/^v/, '')}`);
  }
});
test('current version recovers missing tag without another commit', async () => {
  const { writes, refs } = await scenario({ latest: 'v5.1.0' });
  assert.equal(writes.length, 0);
  assert.equal(refs[0].sha, 'inspected-head');
});
test('existing release tags are never recreated or moved', async () => {
  assert.deepEqual(await scenario({ latest: 'v5.1.0', exists: true }), { writes: [], refs: [] });
});
test('older upstream releases do not commit or tag', async () => {
  for (const latest of ['v5.0.9', 'v4.99.99']) {
    assert.deepEqual(await scenario({ latest }), { writes: [], refs: [] });
  }
});
test('invalid releases and Dockerfiles fail', async () => {
  for (const args of [{ latest: 'v5.2.0-rc1' }, { prerelease: true },
    { source: 'FROM scratch\n' },
    { source: 'ARG WEEWX_RELEASE=v5.1.0\nARG WEEWX_RELEASE=v5.1.0\n' }]) {
    await assert.rejects(scenario(args));
  }
});
test('API errors propagate instead of being treated as missing tags', async () => {
  await assert.rejects(scenario({ lookupStatus: 403 }), /lookup failed/);
  await assert.rejects(scenario({ commitFails: true }), /conflict/);
});
