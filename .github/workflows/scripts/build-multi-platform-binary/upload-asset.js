const { execSync } = require('child_process');
const fs = require('fs');

async function uploadAsset() {
  const releaseId = process.env.RELEASE_ID;
  const assetPath = process.env.ASSET_PATH;
  const assetName = process.env.ASSET_NAME;
  const token = process.env.GITHUB_TOKEN;

  if (!releaseId || !assetPath || !assetName || !token) {
    console.error('RELEASE_ID, ASSET_PATH, ASSET_NAME, and GITHUB_TOKEN environment variables are required');
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

  // Check if asset file exists
  if (!fs.existsSync(assetPath)) {
    console.error(`Asset file not found: ${assetPath}`);
    process.exit(1);
  }

  const assetData = fs.readFileSync(assetPath);
  const assetSize = fs.statSync(assetPath).size;

  console.log(`Uploading asset: ${assetName} (${(assetSize / 1024 / 1024).toFixed(2)} MB) to release ${releaseId}`);

  try {
    const uploadUrl = `https://uploads.github.com/repos/${owner}/${repo}/releases/${releaseId}/assets?name=${encodeURIComponent(assetName)}`;

    const response = await fetch(uploadUrl, {
      method: 'POST',
      headers: {
        'Authorization': `token ${token}`,
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/zip',
        'Content-Length': assetSize.toString(),
        'User-Agent': 'GitHub-Actions'
      },
      body: assetData
    });

    if (response.status === 201) {
      const result = await response.json();
      console.log(`Asset uploaded successfully: ${result.name}`);
      console.log(`Download URL: ${result.browser_download_url}`);
    } else {
      console.error(`Upload failed with status: ${response.status}`);
      const errorText = await response.text();
      console.error(`Response: ${errorText}`);
      process.exit(1);
    }
  } catch (error) {
    console.error('Error uploading asset:', error.message);
    process.exit(1);
  }
}

uploadAsset();
