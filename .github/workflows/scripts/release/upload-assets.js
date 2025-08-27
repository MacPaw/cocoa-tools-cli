const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

async function uploadAssets() {
  const releaseId = process.env.RELEASE_ID;
  const token = process.env.GITHUB_TOKEN;
  const artifactsPath = process.env.ARTIFACTS_PATH || 'artifacts';

  if (!releaseId || !token) {
    console.error('RELEASE_ID and GITHUB_TOKEN environment variables are required');
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

  console.log(`Uploading assets to release ${releaseId} in ${owner}/${repo}`);

  // Check if artifacts directory exists
  if (!fs.existsSync(artifactsPath)) {
    console.error(`Artifacts directory not found: ${artifactsPath}`);
    process.exit(1);
  }

  try {
    // Read all artifact directories
    const artifactDirs = fs.readdirSync(artifactsPath, { withFileTypes: true })
      .filter(dirent => dirent.isDirectory())
      .map(dirent => dirent.name);

    if (artifactDirs.length === 0) {
      console.log('No artifact directories found');
      return;
    }

    console.log(`Found ${artifactDirs.length} artifact directories: ${artifactDirs.join(', ')}`);

    let uploadCount = 0;

    // Process each artifact directory
    for (const artifactDir of artifactDirs) {
      const artifactDirPath = path.join(artifactsPath, artifactDir);
      console.log(`Processing artifact directory: ${artifactDir}`);

      // Find all .zip files in the artifact directory
      const zipFiles = fs.readdirSync(artifactDirPath)
        .filter(file => file.endsWith('.zip'))
        .map(file => path.join(artifactDirPath, file));

      if (zipFiles.length === 0) {
        console.log(`No .zip files found in ${artifactDir}`);
        continue;
      }

      // Upload each zip file
      for (const assetPath of zipFiles) {
        const assetName = path.basename(assetPath);

        if (!fs.existsSync(assetPath)) {
          console.error(`Asset file not found: ${assetPath}`);
          continue;
        }

        const assetData = fs.readFileSync(assetPath);
        const assetSize = fs.statSync(assetPath).size;

        console.log(`Uploading ${assetName} (${(assetSize / 1024 / 1024).toFixed(2)} MB)...`);

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
          console.log(`✅ Successfully uploaded: ${result.name}`);
          console.log(`   Download URL: ${result.browser_download_url}`);
          uploadCount++;
        } else {
          console.error(`❌ Upload failed for ${assetName} with status: ${response.status}`);
          const errorText = await response.text();
          console.error(`   Response: ${errorText}`);
          process.exit(1);
        }
      }
    }

    console.log(`\n🎉 Successfully uploaded ${uploadCount} assets to release ${releaseId}`);

  } catch (error) {
    console.error('Error uploading assets:', error.message);
    process.exit(1);
  }
}

uploadAssets();
