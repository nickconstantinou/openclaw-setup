#!/usr/bin/env node
/**
 * Buffer GraphQL API Skill - Free Plan Compatible
 * 
 * Free Plan Limits:
 * - 3 channels max
 * - 10 scheduled posts per channel
 * - 100 ideas
 * - Basic analytics
 * 
 * Use 'node buffer.js limits' to check remaining quota
 */

const BUFFER_API = 'https://api.buffer.com';
const API_KEY = process.env.BUFFER_API_KEY;

async function graphql(query) {
  if (!API_KEY) throw new Error('BUFFER_API_KEY not set');
  
  const res = await fetch(BUFFER_API, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${API_KEY}` },
    body: JSON.stringify({ query })
  });
  
  const data = await res.json();
  if (data.errors) throw new Error(JSON.stringify(data.errors));
  return data.data;
}

async function getOrgId() {
  const d = await graphql(`{ account { organizations { id name } } }`);
  return d.account.organizations[0]?.id;
}

// ============ QUERIES ============

async function getAccount() {
  return graphql(`{ account { id email name avatar timezone organizations { id name } } }`);
}

async function getChannels() {
  const orgId = await getOrgId();
  return graphql(`{ channels(input: {organizationId: "${orgId}"}) { id name descriptor service avatar isDisconnected isLocked } }`);
}

async function getChannel(id) {
  return graphql(`{ channel(input: {id: "${id}"}) { id name descriptor service avatar timezone isDisconnected isLocked postingGoal { dailyLimit dailyRemaining } } }`);
}

async function getPosts(channelId, limit = 10) {
  const orgId = await getOrgId();
  return graphql(`{ posts(input: {organizationId: "${orgId}", channelId: "${channelId}", first: ${limit}) { edges { node { id text status type createdAt scheduledAt } } } }`);
}

async function getDailyLimits(channelIds) {
  return graphql(`{ dailyPostingLimits(input: {channelIds: [${channelIds.map(id => `"${id}"`).join(',')}]}) { channelId sent scheduled limit isAtLimit } }`);
}

// Get idea count
async function getIdeaCount() {
  const orgId = await getOrgId();
  // Free plan has 100 ideas max
  return graphql(`{ ideas(input: {organizationId: "${orgId}", first: 100}) { total } }`).catch(() => ({ ideas: { total: 'unknown' } }));
}

// ============ MUTATIONS ============

async function createIdea(text, title = '') {
  const orgId = await getOrgId();
  const t = title ? `, title: "${title}"` : '';
  return graphql(`mutation { createIdea(input: { organizationId: "${orgId}", content: { text: "${text}"${t} }) { ... on Idea { id content { text title } } } }`);
}

async function createPost(channelId, text, options = {}) {
  const { scheduledAt = null, mediaUrl = null } = options;
  let extra = '';
  if (scheduledAt) extra += `, scheduledAt: "${scheduledAt}"`;
  if (mediaUrl) extra += `, media: { url: "${mediaUrl}" }`;
  return graphql(`mutation { createPost(input: { channelId: "${channelId}", text: "${text}"${extra} }) { ... on Post { id text status } } }`);
}

async function deletePost(postId) {
  return graphql(`mutation { deletePost(input: { id: "${postId}" }) { ... on Post { id } } }`);
}

// ============ CLI ============

const args = process.argv.slice(2);
const cmd = args[0];

const FREE_PLAN_LIMITS = {
  channels: 3,
  postsPerChannel: 10,
  ideas: 100
};

const commands = {
  account: async () => {
    const a = await getAccount();
    console.log('\n📧 Account:', a.account.email);
    console.log('   Name:', a.account.name || 'Not set');
    console.log('   Orgs:', a.account.organizations.map(o => o.name).join(', '));
    console.log('\n📊 Free Plan Limits:');
    console.log('   3 channels max | 10 posts/channel | 100 ideas');
  },

  channels: async () => {
    const c = await getChannels();
    console.log('\n📱 Channels:');
    console.log(`   (Free plan: ${c.channels.length}/3 used)`);
    if (c.channels.length === 0) {
      console.log('   No channels. Add up to 3 in Buffer app.');
    }
    c.channels.forEach(ch => {
      const status = ch.isDisconnected ? '⚠️ Disconnected' : (ch.isLocked ? '🔒 Locked' : '✅');
      console.log(`   ${status} [${ch.service}] ${ch.name} (${ch.id})`);
    });
  },

  channel: async () => {
    if (!args[1]) throw new Error('Usage: buffer.js channel [id]');
    const c = await getChannel(args[1]);
    console.log('\n📱 Channel:', c.channel.name);
    console.log('   Service:', c.channel.service, '-', c.channel.descriptor);
    console.log('   Timezone:', c.channel.timezone);
    const status = c.channel.isDisconnected ? '⚠️ Disconnected' : (c.channel.isLocked ? '🔒 Locked' : '✅ Connected');
    console.log('   Status:', status);
    if (c.channel.postingGoal) {
      console.log('   Posting Goal:', `${c.channel.postingGoal.dailyRemaining}/${c.channel.postingGoal.dailyLimit} remaining today`);
    }
  },

  posts: async () => {
    if (!args[1]) throw new Error('Usage: buffer.js posts [channel_id] [limit]');
    const limit = parseInt(args[2]) || 10;
    const p = await getPosts(args[1], limit);
    console.log('\n📝 Posts:');
    const posts = p.posts.edges;
    if (posts.length === 0) console.log('   No posts');
    posts.forEach(e => console.log(`   [${e.node.status}] ${e.node.text.substring(0, 50)}...`));
  },

  post: async () => {
    const text = args.slice(1).join(' ');
    if (!text) throw new Error('Usage: buffer.js post "text" [title]');
    console.log('\n📝 Creating idea (Free plan: 100 max)...');
    const r = await createIdea(text, args[2] || '');
    console.log('✅ Created:', r.createIdea);
    console.log('   Ideas remaining: ~99');
  },

  create: async () => {
    const channelId = args[1];
    const text = args.slice(2).join(' ');
    if (!channelId || !text) throw new Error('Usage: buffer.js create [channel_id] "text"');
    
    // Check limits first
    const limits = await getDailyLimits([channelId]);
    const limit = limits.dailyPostingLimits[0];
    
    if (limit && limit.isAtLimit) {
      console.log('⚠️ Daily post limit reached (10/10 on free plan)');
      console.log('   Wait or upgrade to Essentials plan');
      return;
    }
    
    console.log('\n📝 Creating post...');
    const r = await createPost(channelId, text);
    console.log('✅ Created:', r.createPost);
    console.log(`   Posts today: ${limit ? limit.sent + 1 : 1}/10`);
  },

  delete: async () => {
    if (!args[1]) throw new Error('Usage: buffer.js delete [post_id]');
    const r = await deletePost(args[1]);
    console.log('✅ Deleted:', r.deletePost);
  },

  limits: async () => {
    const channels = await getChannels();
    const ids = channels.channels.map(c => c.id);
    
    console.log('\n📊 Free Plan Status:');
    console.log(`   Channels: ${channels.channels.length}/3`);
    
    if (ids.length > 0) {
      const limits = await getDailyLimits(ids);
      limits.dailyPostingLimits.forEach(l => {
        const used = l.sent + l.scheduled;
        const total = l.limit || 10;
        const pct = Math.round((used / total) * 100);
        console.log(`   Channel ${l.channelId}: ${used}/${total} posts (${pct}%) ${l.isAtLimit ? '⚠️ LIMIT' : '✅'}`);
      });
    }
    
    console.log('\n💡 Upgrade to Essentials ($5/mo) for unlimited posts');
  },

  status: async () => {
    await commands.limits();
  },

  help: () => {
    console.log(`
Buffer API Skill - Free Plan

📊 PLAN LIMITS:
   3 channels | 10 posts/channel | 100 ideas

📋 COMMANDS:
   account                  Account info + limits
   channels                 List channels (3 max)
   channel [id]           Channel details
   posts [id] [n]         Posts for channel
   post "text" [title]   Create idea (100 max)
   create [id] "text"    Create post (10/day)
   delete [post_id]       Delete post
   limits                  Check quota usage
   status                  Quick status check

📱 SETUP:
   Add channels in Buffer app first

💡 GET MORE:
   Upgrade to Essentials ($5/mo) for unlimited

🌐 Get API key: https://publish.buffer.com/settings/api
`);
  }
};

(async () => {
  try {
    await (commands[cmd] || commands.help)();
  } catch (e) {
    console.error('❌', e.message);
    process.exit(1);
  }
})();
