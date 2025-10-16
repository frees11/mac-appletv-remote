const { notarize } = require('@electron/notarize');

exports.default = async function notarizing(context) {
  const { electronPlatformName, appOutDir } = context;

  if (electronPlatformName !== 'darwin') {
    return;
  }

  const appId = 'com.atv.remote';
  const appPath = `${appOutDir}/ATV Remote.app`;

  // Check if code signing is disabled
  if (process.env.CSC_IDENTITY_AUTO_DISCOVERY === 'false') {
    console.log('⚠️  Skipping notarization: Code signing is disabled (CSC_IDENTITY_AUTO_DISCOVERY=false)');
    return;
  }

  const appleId = process.env.NOTARIZE_APPLE_ID || process.env.APPLE_ID;
  const appleIdPassword = process.env.NOTARIZE_APPLE_PASSWORD || process.env.APPLE_APP_SPECIFIC_PASSWORD;
  const teamId = process.env.NOTARIZE_TEAM_ID || process.env.APPLE_TEAM_ID;

  if (!appleId || !appleIdPassword || !teamId) {
    console.log('⚠️  Skipping notarization: Missing Apple credentials in environment');
    return;
  }

  console.log('');
  console.log('========================================');
  console.log('🔐 CUSTOM NOTARIZATION STARTING');
  console.log('========================================');
  console.log(`📱 App: ${appId}`);
  console.log(`📁 Path: ${appPath}`);
  console.log(`👤 Apple ID: ${appleId}`);
  console.log(`🏢 Team ID: ${teamId}`);
  console.log('⏳ Uploading to Apple for notarization...');
  console.log('   (This can take 1-10 minutes)')
  console.log('========================================');
  console.log('');

  try {
    await notarize({
      appPath: appPath,
      appleId: appleId,
      appleIdPassword: appleIdPassword,
      teamId: teamId,
    });
    console.log('');
    console.log('========================================');
    console.log('✅ NOTARIZATION COMPLETE!');
    console.log('========================================');
    console.log('Your app is now signed and notarized by Apple');
    console.log('Users can install without warnings!');
    console.log('========================================');
    console.log('');
  } catch (error) {
    console.log('');
    console.log('========================================');
    console.log('❌ NOTARIZATION FAILED');
    console.log('========================================');
    console.error('Error:', error);
    console.log('========================================');
    console.log('');
    throw error;
  }
};
