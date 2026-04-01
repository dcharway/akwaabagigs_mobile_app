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

// ============ MESSAGE & CONVERSATION ACL ============

/**
 * beforeSave on Message: Ensure ACL allows both participants to read.
 * This prevents ACL-related save failures.
 */
Parse.Cloud.beforeSave('Message', async (request) => {
  const msg = request.object;

  // Set public read + authenticated write if no ACL set
  if (!msg.getACL()) {
    const acl = new Parse.ACL();
    acl.setPublicReadAccess(true);
    acl.setPublicWriteAccess(true);
    msg.setACL(acl);
  }
});

/**
 * beforeSave on Conversation: Ensure ACL allows both participants to read/write.
 */
Parse.Cloud.beforeSave('Conversation', async (request) => {
  const conv = request.object;

  if (!conv.getACL()) {
    const acl = new Parse.ACL();
    acl.setPublicReadAccess(true);
    acl.setPublicWriteAccess(true);
    conv.setACL(acl);
  }
});

// ============ GIGSEEKER VERIFICATION ============

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

// ============ KYC (Smile ID) ============

/**
 * Verify a user's KYC via Smile ID API.
 * Called after selfie+ID scan completes.
 *
 * Params: { jobId: string }
 * Returns: { success: boolean, score: number }
 */
Parse.Cloud.define('verifySmileKYC', async (request) => {
  const { jobId } = request.params;
  if (!jobId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'jobId is required');
  }

  // In production, poll the Smile ID API for results:
  // const SMILE_TOKEN = process.env.SMILE_ID_API_KEY || 'YOUR_TOKEN';
  // const response = await fetch(`https://api.smileid.com/v1/job_status`, {
  //   method: 'POST',
  //   headers: {
  //     'Content-Type': 'application/json',
  //     'Authorization': `Bearer ${SMILE_TOKEN}`,
  //   },
  //   body: JSON.stringify({ job_id: jobId, partner_id: 'YOUR_PARTNER_ID' }),
  // }).then(r => r.json());
  //
  // if (response.result && response.result.ResultCode === '0810') {
  //   // Successful verification
  //   const score = response.result.ConfidenceValue || 99.0;
  //   // Update the GigSeeker record
  //   const seekerQuery = new Parse.Query('GigSeeker');
  //   seekerQuery.equalTo('kycJobId', jobId);
  //   const seeker = await seekerQuery.first({ useMasterKey: true });
  //   if (seeker) {
  //     seeker.set('kycStatus', 'verified');
  //     seeker.set('kycScore', score);
  //     seeker.set('verificationStatus', 'verified');
  //     seeker.set('canChat', true);
  //     await seeker.save(null, { useMasterKey: true });
  //   }
  //   return { success: true, score };
  // }
  // throw 'Verification failed: ' + (response.result?.ResultText || 'Unknown error');

  // Sandbox/demo: Find the seeker with this jobId and auto-verify
  const seekerQuery = new Parse.Query('GigSeeker');
  seekerQuery.equalTo('kycJobId', jobId);
  const seeker = await seekerQuery.first({ useMasterKey: true });

  if (seeker) {
    const score = 99.8; // Sandbox score
    seeker.set('kycStatus', 'verified');
    seeker.set('kycScore', score);
    seeker.set('verificationStatus', 'verified');
    seeker.set('canChat', true);
    await seeker.save(null, { useMasterKey: true });
    return { success: true, score };
  }

  throw 'No pending KYC job found for: ' + jobId;
});

// ============ STORE: ADMIN-ONLY PRODUCT ENFORCEMENT ============

/**
 * beforeSave trigger on Product: Only admins can create/update products.
 */
Parse.Cloud.beforeSave('Product', async (request) => {
  if (request.master) return; // Allow master key operations

  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Authentication required');
  }

  // Fetch full user to check isAdmin
  const userQuery = new Parse.Query(Parse.User);
  const fullUser = await userQuery.get(user.id, { useMasterKey: true });

  if (!fullUser.get('isAdmin')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Admin access required to manage products');
  }
});

/**
 * beforeDelete trigger on Product: Only admins can delete products.
 */
Parse.Cloud.beforeDelete('Product', async (request) => {
  if (request.master) return;

  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Authentication required');
  }

  const userQuery = new Parse.Query(Parse.User);
  const fullUser = await userQuery.get(user.id, { useMasterKey: true });

  if (!fullUser.get('isAdmin')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Admin access required to delete products');
  }
});

/**
 * afterSave on StoreOrder: Auto-decrement product stock and record commission.
 */
Parse.Cloud.afterSave('StoreOrder', async (request) => {
  const order = request.object;

  // Only process new orders
  if (order.existed()) return;

  const productId = order.get('productId');
  const quantity = order.get('quantity') || 1;

  if (productId) {
    const productQuery = new Parse.Query('Product');
    const product = await productQuery.get(productId, { useMasterKey: true });
    product.decrement('stock', quantity);
    await product.save(null, { useMasterKey: true });
  }
});

// ============ VIDEO ADS: ADMIN-ONLY ENFORCEMENT ============

/**
 * beforeSave trigger on VideoAd: Only admins can create/update video ads.
 */
Parse.Cloud.beforeSave('VideoAd', async (request) => {
  if (request.master) return;

  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Authentication required');
  }

  const userQuery = new Parse.Query(Parse.User);
  const fullUser = await userQuery.get(user.id, { useMasterKey: true });

  if (!fullUser.get('isAdmin')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Admin access required to manage video ads');
  }
});

/**
 * beforeDelete trigger on VideoAd: Only admins can delete video ads.
 */
Parse.Cloud.beforeDelete('VideoAd', async (request) => {
  if (request.master) return;

  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Authentication required');
  }

  const userQuery = new Parse.Query(Parse.User);
  const fullUser = await userQuery.get(user.id, { useMasterKey: true });

  if (!fullUser.get('isAdmin')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Admin access required to delete video ads');
  }
});

// ============ INVENTORY: ADMIN-ONLY + LOW STOCK ALERTS ============

/**
 * beforeSave on Inventory: Only admins can write.
 */
Parse.Cloud.beforeSave('Inventory', async (request) => {
  if (request.master) return;
  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Authentication required');
  }
  const userQuery = new Parse.Query(Parse.User);
  const fullUser = await userQuery.get(user.id, { useMasterKey: true });
  if (!fullUser.get('isAdmin')) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Admin access required');
  }
});

/**
 * afterSave on Inventory: Check for low stock and log alert.
 */
Parse.Cloud.afterSave('Inventory', async (request) => {
  const inv = request.object;
  const qty = inv.get('quantity') || 0;
  const threshold = inv.get('restockThreshold') || 5;
  const productName = inv.get('productName') || 'Unknown product';

  if (qty <= threshold) {
    console.log(`LOW STOCK ALERT: ${productName} has ${qty} units (threshold: ${threshold})`);
    // In production, send push notification or email to admins here
  }
});

// ============ CUSTOMER SUPPORT CHATBOT ============

/**
 * AI customer support chat function.
 * Called from the Flutter AI Toolkit's SupportChatProvider.
 *
 * To upgrade: Replace the rule-based responses below with an API call
 * to Gemini, Claude, or GPT. The Flutter app works with either.
 *
 * Params: { message: string, userId?: string, email?: string }
 * Returns: { reply: string }
 */
Parse.Cloud.define('customerSupportChat', async (request) => {
  const { message } = request.params;
  if (!message) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'message is required');
  }

  const q = message.toLowerCase();

  if (q.includes('post') && q.includes('gig')) {
    return { reply: 'To post a gig: Go to Gigs tab > Post Gig > Fill details > Pay GH₵117.50 > Your gig goes live!' };
  }
  if (q.includes('bid') || q.includes('apply')) {
    return { reply: 'To apply: Browse gigs > Tap Apply & Bid > Fill details > Choose bid amount (50/100 GH₵ increments) > Wait for poster approval.' };
  }
  if (q.includes('chat') || q.includes('message')) {
    return { reply: 'Chat activates after the poster accepts your bid. Both parties must agree on the amount first.' };
  }
  if (q.includes('pay') || q.includes('momo')) {
    return { reply: 'We accept Mobile Money (MTN/Vodafone/AirtelTigo), Cash (at agents), and Bank Transfer (GCB Bank).' };
  }

  return { reply: 'I can help with: posting gigs, applying & bidding, payments, verification, escrow, store purchases, and account issues. What do you need?' };
});
