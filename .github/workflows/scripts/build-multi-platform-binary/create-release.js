const { execSync } = require('child_process');
const fs = require('fs');

async function createTagAndRelease() {
  const tagName = process.env.TAG_NAME;
  const token = process.env.GITHUB_TOKEN;
  const isPrerelease = process.env.IS_PRERELEASE === 'true';

  if (!tagName || !token) {
    console.error('TAG_NAME and GITHUB_TOKEN environment variables are required');
    process.exit(1);
  }

  // Get repository info from git remote
  const remoteUrl = execSync('git remote get-url origin', { encoding: 'utf8' }).trim();
  const repoMatch = remoteUrl.match(/github\.com[:/]([^/]+)\/([^/.]+)/);

  if (!repoMatch) {
    console.error('Could not parse GitHub repository from remote URL');
    process.exit(1);
  }

  const [, owner, repo] = repoMatch;

  console.log(`Creating tag and release for: ${tagName} in ${owner}/${repo} (prerelease: ${isPrerelease})`);

  try {
    // Get the current commit SHA
    const commitSha = execSync('git rev-parse HEAD', { encoding: 'utf8' }).trim();
    console.log(`Current commit SHA: ${commitSha}`);

    // Create the tag
    console.log(`Creating tag: ${tagName}`);
    const tagResponse = await fetch(`https://api.github.com/repos/${owner}/${repo}/git/refs`, {
      method: 'POST',
      headers: {
        'Authorization': `token ${token}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'GitHub-Actions',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        ref: `refs/tags/${tagName}`,
        sha: commitSha
      })
    });

    if (tagResponse.status === 201) {
      console.log(`Tag created successfully: ${tagName}`);
    } else {
      const errorText = await tagResponse.text();
      console.error(`Failed to create tag: ${tagResponse.status}`);
      console.error(`Response: ${errorText}`);
      process.exit(1);
    }

    // Create the release
    console.log(`Creating release: ${tagName}`);
    const releaseResponse = await fetch(`https://api.github.com/repos/${owner}/${repo}/releases`, {
      method: 'POST',
      headers: {
        'Authorization': `token ${token}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'GitHub-Actions',
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        tag_name: tagName,
        name: tagName,
        draft: false,
        prerelease: isPrerelease,
        generate_release_notes: true
      })
    });

    if (releaseResponse.status === 201) {
      const release = await releaseResponse.json();
      console.log(`Release created successfully: ${release.name} (ID: ${release.id})`);

      // Set outputs for GitHub Actions
      fs.appendFileSync(process.env.GITHUB_OUTPUT, `release_id=${release.id}\n`);
      fs.appendFileSync(process.env.GITHUB_OUTPUT, `release_url=${release.html_url}\n`);
    } else {
      const errorText = await releaseResponse.text();
      console.error(`Failed to create release: ${releaseResponse.status}`);
      console.error(`Response: ${errorText}`);
      process.exit(1);
    }

  } catch (error) {
    console.error('Error creating tag and release:', error.message);
    process.exit(1);
  }
}

createTagAndRelease();
