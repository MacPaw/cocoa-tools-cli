const { execSync } = require('child_process');
const fs = require('fs');

async function checkTagAndRelease() {
  const tagName = process.env.VERSION;
  const token = process.env.GITHUB_TOKEN;

  if (!tagName || !token) {
    console.error('VERSION and GITHUB_TOKEN environment variables are required');
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

  console.log(`Checking tag and release for: ${tagName} in ${owner}/${repo}`);

  let tagExists = false;
  let releaseExists = false;

  try {
    // Check if tag exists
    console.log('Checking if tag exists...');
    const tagResponse = await fetch(`https://api.github.com/repos/${owner}/${repo}/git/refs/tags/${tagName}`, {
      headers: {
        'Authorization': `token ${token}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'GitHub-Actions'
      }
    });

    if (tagResponse.status === 200) {
      // tagResponse returns a list of tags matching the tag prefix,
      // we need to check if the tag exists
      // in the list by comparing the tag name with the tag.ref
      const tags = await tagResponse.json();
      tagExists = tags.some(tag => tag.ref === `refs/tags/${tagName}`);
      console.log(`Tag exists: ${tagExists}`);
    } else if (tagResponse.status === 404) {
      console.log(`Tag does not exist: ${tagName}`);
    } else {
      console.error(`Tag check failed with status: ${tagResponse.status}`);
      const errorText = await tagResponse.text();
      console.error(`Response: ${errorText}`);
      process.exit(1);
    }

    // Check if release exists
    console.log('Checking if release exists...');
    const releaseResponse = await fetch(`https://api.github.com/repos/${owner}/${repo}/releases/tags/${tagName}`, {
      headers: {
        'Authorization': `token ${token}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'GitHub-Actions'
      }
    });

    if (releaseResponse.status === 200) {
      const release = await releaseResponse.json();
      console.log(`Release exists: ${release.name} (ID: ${release.id})`);
      releaseExists = true;
    } else if (releaseResponse.status === 404) {
      console.log(`Release does not exist: ${tagName}`);
    } else {
      console.error(`Release check failed with status: ${releaseResponse.status}`);
      const errorText = await releaseResponse.text();
      console.error(`Response: ${errorText}`);
      process.exit(1);
    }

    // Set outputs for GitHub Actions
    const shouldProceed = !tagExists && !releaseExists;

    fs.appendFileSync(process.env.GITHUB_OUTPUT, `tag_exists=${tagExists}\n`);
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `release_exists=${releaseExists}\n`);
    fs.appendFileSync(process.env.GITHUB_OUTPUT, `should_proceed=${shouldProceed}\n`);

    console.log(`Tag exists: ${tagExists}`);
    console.log(`Release exists: ${releaseExists}`);
    console.log(`Should proceed with build and release: ${shouldProceed}`);

  } catch (error) {
    console.error('Error checking tag and release:', error.message);
    process.exit(1);
  }
}

checkTagAndRelease();
