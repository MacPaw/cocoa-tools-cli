const { execSync } = require('child_process');
const fs = require('fs');

async function checkAsset() {
  const releaseId = process.env.RELEASE_ID;
  const tagName = process.env.TAG_NAME;
  const token = process.env.GITHUB_TOKEN;
  const platform = process.env.PLATFORM;
  const arch = process.env.ARCH;
  const binaryName = process.env.BINARY_NAME;

  if (!releaseId || !tagName || !token || !platform || !arch || !binaryName) {
    console.error('RELEASE_ID, TAG_NAME, OS, ARCH, BINARY_NAME, and GITHUB_TOKEN environment variables are required');
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

  // Extract version from tag (remove 'v' prefix if present)
  const version = tagName.replace(/^v/, '');
  const expectedAssetName = `${binaryName}-${version}-${platform}-${arch}.zip`;

  console.log(`Checking for asset: ${expectedAssetName} in release ${releaseId}`);

  try {
    const response = await fetch(`https://api.github.com/repos/${owner}/${repo}/releases/${releaseId}/assets`, {
      headers: {
        'Authorization': `token ${token}`,
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'GitHub-Actions'
      }
    });

    if (response.status === 200) {
      const assets = await response.json();
      const existingAsset = assets.find(asset => asset.name === expectedAssetName);

      if (existingAsset) {
        console.log(`Asset already exists: ${existingAsset.name} (ID: ${existingAsset.id})`);
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `asset_exists=true\n`);
      } else {
        console.log('Asset does not exist, proceeding with build');
        fs.appendFileSync(process.env.GITHUB_OUTPUT, `asset_exists=false\n`);
      }
    } else {
      console.error(`API request failed with status: ${response.status}`);
      const errorText = await response.text();
      console.error(`Response: ${errorText}`);
      process.exit(1);
    }
  } catch (error) {
    console.error('Error checking asset:', error.message);
    process.exit(1);
  }
}

checkAsset();
