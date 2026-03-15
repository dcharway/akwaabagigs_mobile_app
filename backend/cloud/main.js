// ============================================================
// Akwaaba Gigs — Back4App Cloud Code
// Deploy via: Back4App Dashboard > Cloud Code Functions
// ============================================================

// ============ BEFORE SAVE HOOKS ============

// Auto-populate job metadata on save
Parse.Cloud.beforeSave('Job', async (request) => {
  const job = request.object;
  if (job.isNew()) {
    if (!job.get('postedDate')) {
      job.set('postedDate', new Date().toISOString());
    }
    if (!job.get('status')) {
      job.set('status', 'active');
    }
  }
});

// Auto-populate application metadata
Parse.Cloud.beforeSave('Application', async (request) => {
  const app = request.object;
  if (app.isNew()) {
    if (!app.get('applicationDate')) {
      app.set('applicationDate', new Date().toISOString());
    }
    if (!app.get('status')) {
      app.set('status', 'pending_verification');
    }

    // Look up job title/company for the application
    const jobId = app.get('jobId');
    if (jobId) {
      const jobQuery = new Parse.Query('Job');
      try {
        const job = await jobQuery.get(jobId, { useMasterKey: true });
        app.set('jobTitle', job.get('title'));
        app.set('jobCompany', job.get('company'));
      } catch (e) {
        // Job not found — leave fields empty
      }
    }
  }
});

// Set defaults for GigSeeker
Parse.Cloud.beforeSave('GigSeeker', async (request) => {
  const seeker = request.object;
  if (seeker.isNew()) {
    if (!seeker.get('verificationStatus')) {
      seeker.set('verificationStatus', 'unverified');
    }
    if (seeker.get('canChat') === undefined) {
      seeker.set('canChat', false);
    }
  }
});

// Set defaults for GigPoster
Parse.Cloud.beforeSave('GigPoster', async (request) => {
  const poster = request.object;
  if (poster.isNew()) {
    if (!poster.get('verificationStatus')) {
      poster.set('verificationStatus', 'unverified');
    }
  }
});

// ============ AFTER SAVE HOOKS ============

// Update conversation lastMessageAt when a new message is saved
Parse.Cloud.afterSave('Message', async (request) => {
  const message = request.object;
  if (request.context?.skipAfterSave) return;

  const conversationId = message.get('conversationId');
  if (conversationId) {
    const query = new Parse.Query('Conversation');
    try {
      const conversation = await query.get(conversationId, { useMasterKey: true });
      conversation.set('lastMessageAt', new Date().toISOString());
      await conversation.save(null, { useMasterKey: true });
    } catch (e) {
      console.error('Failed to update conversation lastMessageAt:', e);
    }
  }
});

// ============ CLOUD FUNCTIONS ============

// Get jobs for the current poster
Parse.Cloud.define('getMyPostedJobs', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Not authenticated');

  const query = new Parse.Query('Job');
  query.equalTo('posterId', user.id);
  query.descending('createdAt');
  return await query.find({ useMasterKey: true });
});

// Get conversations for current user
Parse.Cloud.define('getMyConversations', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Not authenticated');

  const posterQuery = new Parse.Query('Conversation');
  posterQuery.equalTo('posterId', user.id);

  const seekerQuery = new Parse.Query('Conversation');
  seekerQuery.equalTo('seekerEmail', user.getEmail());

  const mainQuery = Parse.Query.or(posterQuery, seekerQuery);
  mainQuery.descending('lastMessageAt');

  return await mainQuery.find({ useMasterKey: true });
});

// Get seeker rating summary
Parse.Cloud.define('getSeekerRatings', async (request) => {
  const { email } = request.params;
  if (!email) throw new Parse.Error(400, 'Email is required');

  // Find seeker by email
  const seekerQuery = new Parse.Query('GigSeeker');
  seekerQuery.equalTo('email', email);
  const seeker = await seekerQuery.first({ useMasterKey: true });
  if (!seeker) {
    return { averageRating: 0, totalRatings: 0, ratings: [] };
  }

  // Get ratings for this seeker
  const ratingQuery = new Parse.Query('Rating');
  ratingQuery.equalTo('gigSeekerId', seeker.id);
  ratingQuery.descending('createdAt');
  const ratings = await ratingQuery.find({ useMasterKey: true });

  if (ratings.length === 0) {
    return { averageRating: 0, totalRatings: 0, ratings: [] };
  }

  const total = ratings.reduce((sum, r) => sum + r.get('rating'), 0);
  const average = total / ratings.length;

  return {
    averageRating: average,
    totalRatings: ratings.length,
    ratings: ratings.map(r => ({
      id: r.id,
      jobId: r.get('jobId'),
      applicationId: r.get('applicationId'),
      posterId: r.get('posterId'),
      posterName: r.get('posterName'),
      gigSeekerId: r.get('gigSeekerId'),
      gigSeekerName: r.get('gigSeekerName'),
      rating: r.get('rating'),
      review: r.get('review'),
      createdAt: r.createdAt.toISOString(),
    })),
  };
});

// Check if a rating already exists
Parse.Cloud.define('checkRatingExists', async (request) => {
  const { jobId, applicationId } = request.params;
  if (!jobId || !applicationId) {
    throw new Parse.Error(400, 'jobId and applicationId are required');
  }

  const query = new Parse.Query('Rating');
  query.equalTo('jobId', jobId);
  query.equalTo('applicationId', applicationId);
  const count = await query.count({ useMasterKey: true });

  return { exists: count > 0 };
});

// Submit verification for gig poster
Parse.Cloud.define('submitVerification', async (request) => {
  const user = request.user;
  if (!user) throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Not authenticated');

  const { ghCardNumber, contactPhone } = request.params;
  if (!ghCardNumber || !contactPhone) {
    throw new Parse.Error(400, 'ghCardNumber and contactPhone are required');
  }

  const query = new Parse.Query('GigPoster');
  query.equalTo('userId', user.id);
  const poster = await query.first({ useMasterKey: true });
  if (!poster) {
    throw new Parse.Error(404, 'Poster profile not found');
  }

  poster.set('ghCardNumber', ghCardNumber);
  poster.set('contactPhone', contactPhone);
  poster.set('verificationStatus', 'pending');
  await poster.save(null, { useMasterKey: true });

  return { success: true, message: 'Verification submitted' };
});

// Report a message
Parse.Cloud.define('reportMessage', async (request) => {
  const { messageId } = request.params;
  if (!messageId) throw new Parse.Error(400, 'messageId is required');

  const query = new Parse.Query('Message');
  const message = await query.get(messageId, { useMasterKey: true });
  message.set('flagged', 'reported');
  message.set('flagCategory', 'user_report');
  await message.save(null, { useMasterKey: true });

  return { success: true };
});

// ============ USER AFTER SAVE ============

// When a user signs up, set default role
Parse.Cloud.afterSave(Parse.User, async (request) => {
  if (request.context?.skipAfterSave) return;
  const user = request.object;

  // Only for new users
  if (user.existed()) return;

  // Ensure firstName/lastName are set
  if (!user.get('firstName')) {
    user.set('firstName', '');
  }
  if (!user.get('lastName')) {
    user.set('lastName', '');
  }
});
