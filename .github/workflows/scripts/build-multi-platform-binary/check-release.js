const { execSync } = require('child_process');
const fs = require('fs');

async function createRelease(owner, repo, tagName, token, isPrerelease = false) {
  console.log(`Creating release for tag: ${tagName} (prerelease: ${isPrerelease})`);

  try {
    const response = await fetch(`https://api.github.com/repos/${owner}/${repo}/releases`, {
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

    if (response.status === 201) {
      const release = await response.json();
      console.log(`Release created successfully: ${release.name} (ID: ${release.id})`);
      return release;
    } else {
      const errorText = await response.text();
      console.error(`Failed to create release: ${response.status}`);
      console.error(`Response: ${errorText}`);
      process.exit(1);
    }
  } catch (error) {
    console.error('Error creating release:', error.message);
    process.exit(1);
  }
}

async function checkOrCreateRelease() {
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

  console.log(`Checking release for tag: ${tagName} in ${owner}/${repo}`);

  try {
    const response = await fetch(`https://api.github.com/repos/${owner}/${repo}/releases/tags/${tagName}`, {
      headers: {
        'Authorization': `token ${token}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'GitHub-Actions'
      }
    });

    if (response.status === 200) {
      const release = await response.json();
      console.log(`Release exists: ${release.name} (ID: ${release.id})`);

      // Set outputs for GitHub Actions
      fs.appendFileSync(process.env.GITHUB_OUTPUT, `release_exists=true\n`);
      fs.appendFileSync(process.env.GITHUB_OUTPUT, `release_id=${release.id}\n`);
    } else if (response.status === 404) {
      console.log('Release does not exist, creating new release...');

      // Create a new release
      const newRelease = await createRelease(owner, repo, tagName, token, isPrerelease);

      // Set outputs for GitHub Actions
      fs.appendFileSync(process.env.GITHUB_OUTPUT, `release_exists=true\n`);
      fs.appendFileSync(process.env.GITHUB_OUTPUT, `release_id=${newRelease.id}\n`);
    } else {
      console.error(`API request failed with status: ${response.status}`);
      const errorText = await response.text();
      console.error(`Response: ${errorText}`);
      process.exit(1);
    }
  } catch (error) {
    console.error('Error checking/creating release:', error.message);
    process.exit(1);
  }
}

checkOrCreateRelease();
