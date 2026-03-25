/**
 * Akwaaba Gigs - Back4App Cloud Code
 *
 * Deploy to Back4App:
 *   1. Go to https://dashboard.back4app.com
 *   2. Select your app > App Settings > Cloud Code Functions
 *   3. Upload this file as main.js (or paste contents)
 *   4. Click "Deploy"
 *
 * This provides:
 *   - beforeSave trigger on GigSeeker: auto-syncs canChat with verificationStatus
 *   - verifyUser(seekerId): Cloud Function to verify a user and enable chat
 *   - unverifyUser(seekerId): Cloud Function to unverify a user and disable chat
 *   - toggleUserChat(seekerId, canChat): Cloud Function to toggle chat access directly
 *   - getVerificationStatus(seekerId): Cloud Function to check a user's status
 *
 * Admin dashboard usage:
 *   Option A: Edit the GigSeeker object directly in the admin panel
 *             Toggle verificationStatus to "verified" → canChat auto-sets to true
 *             Toggle verificationStatus to "unverified" → canChat auto-sets to false
 *
 *   Option B: Toggle canChat boolean directly → verificationStatus auto-syncs
 */

// ============ BEFORE SAVE TRIGGER ============
// When an admin edits a GigSeeker in the dashboard, this trigger keeps
// canChat and verificationStatus in sync automatically.

Parse.Cloud.beforeSave('GigSeeker', async (request) => {
  const seeker = request.object;

  // If this is a new object, ensure defaults
  if (!seeker.existed()) {
    if (seeker.get('canChat') === undefined) {
      seeker.set('canChat', false);
    }
    if (!seeker.get('verificationStatus')) {
      seeker.set('verificationStatus', 'unverified');
    }
    return;
  }

  // Detect which field changed and sync the other
  const dirtyKeys = seeker.dirtyKeys();

  if (dirtyKeys.includes('verificationStatus')) {
    // Admin changed verificationStatus → sync canChat
    const status = seeker.get('verificationStatus');
    if (status === 'verified') {
      seeker.set('canChat', true);
    } else if (status === 'unverified' || status === 'rejected') {
      seeker.set('canChat', false);
    }
    // 'pending' leaves canChat unchanged
  } else if (dirtyKeys.includes('canChat')) {
    // Admin toggled canChat directly → sync verificationStatus
    const canChat = seeker.get('canChat');
    const currentStatus = seeker.get('verificationStatus');
    if (canChat === true && currentStatus !== 'verified') {
      seeker.set('verificationStatus', 'verified');
    } else if (canChat === false && currentStatus === 'verified') {
      seeker.set('verificationStatus', 'unverified');
    }
  }
});

// ============ CLOUD FUNCTIONS ============

/**
 * Verify a gig seeker and enable chat access.
 * Call from admin panel or programmatically.
 *
 * Params: { seekerId: string }
 * Returns: { success: true, seekerId, verificationStatus, canChat }
 */
Parse.Cloud.define('verifyUser', async (request) => {
  const { seekerId } = request.params;
  if (!seekerId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'seekerId is required');
  }

  const query = new Parse.Query('GigSeeker');
  const seeker = await query.get(seekerId, { useMasterKey: true });

  seeker.set('verificationStatus', 'verified');
  seeker.set('canChat', true);
  await seeker.save(null, { useMasterKey: true });

  return {
    success: true,
    seekerId: seeker.id,
    fullName: seeker.get('fullName'),
    email: seeker.get('email'),
    verificationStatus: 'verified',
    canChat: true,
  };
});

/**
 * Unverify a gig seeker and disable chat access.
 *
 * Params: { seekerId: string, reason?: string }
 * Returns: { success: true, seekerId, verificationStatus, canChat }
 */
Parse.Cloud.define('unverifyUser', async (request) => {
  const { seekerId, reason } = request.params;
  if (!seekerId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'seekerId is required');
  }

  const query = new Parse.Query('GigSeeker');
  const seeker = await query.get(seekerId, { useMasterKey: true });

  seeker.set('verificationStatus', 'unverified');
  seeker.set('canChat', false);
  if (reason) {
    seeker.set('rejectionReason', reason);
  }
  await seeker.save(null, { useMasterKey: true });

  return {
    success: true,
    seekerId: seeker.id,
    fullName: seeker.get('fullName'),
    email: seeker.get('email'),
    verificationStatus: 'unverified',
    canChat: false,
  };
});

/**
 * Directly toggle chat access for a gig seeker.
 * This is the simplest toggle — just flip canChat on/off.
 *
 * Params: { seekerId: string, canChat: boolean }
 * Returns: { success: true, seekerId, canChat, verificationStatus }
 */
Parse.Cloud.define('toggleUserChat', async (request) => {
  const { seekerId, canChat } = request.params;
  if (!seekerId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'seekerId is required');
  }
  if (typeof canChat !== 'boolean') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'canChat must be a boolean');
  }

  const query = new Parse.Query('GigSeeker');
  const seeker = await query.get(seekerId, { useMasterKey: true });

  seeker.set('canChat', canChat);
  // The beforeSave trigger will sync verificationStatus automatically
  await seeker.save(null, { useMasterKey: true });

  return {
    success: true,
    seekerId: seeker.id,
    fullName: seeker.get('fullName'),
    email: seeker.get('email'),
    canChat: seeker.get('canChat'),
    verificationStatus: seeker.get('verificationStatus'),
  };
});

/**
 * Get the verification and chat status for a gig seeker.
 *
 * Params: { seekerId: string }
 * Returns: { seekerId, fullName, email, verificationStatus, canChat }
 */
Parse.Cloud.define('getVerificationStatus', async (request) => {
  const { seekerId } = request.params;
  if (!seekerId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'seekerId is required');
  }

  const query = new Parse.Query('GigSeeker');
  const seeker = await query.get(seekerId, { useMasterKey: true });

  return {
    seekerId: seeker.id,
    fullName: seeker.get('fullName'),
    email: seeker.get('email'),
    phone: seeker.get('phone'),
    verificationStatus: seeker.get('verificationStatus'),
    canChat: seeker.get('canChat'),
    createdAt: seeker.createdAt,
  };
});
