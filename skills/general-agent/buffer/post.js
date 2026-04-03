/**
 * Buffer Post Generator
 * Generate social media posts for Buffer queue
 */

const BUFFER_API_KEY = process.env.BUFFER_API_KEY;

/**
 * Generate a week's worth of social posts
 * @param {Object} options
 * @param {string} options.topic - Main topic/book
 * @param {number} options.count - Number of posts
 * @returns {Array} Array of post objects
 */
function generateWeekOfPosts(options = {}) {
  const { topic = 'The Anti-Retirement Guide', count = 7 } = options;
  
  const templates = [
    `Just finished reading ${topic}. Finally, a book that gets it. Retirement isn't about money - it's about identity.`,
    `Question: What does a Tuesday look like when nobody needs you? Worth thinking about before you retire.`,
    `The fear nobody talks about in retirement planning isn't running out of money. It's running out of purpose.`,
    `I wrote this book for people like me - financially ready but emotionally terrified. If that sounds familiar, you're not alone.`,
    `The "one more year" trap. You know it's happening. This book helped me see it clearly.`,
    `Retirement books tell you to run the numbers. Nobody tells you what to do with the Sunday night dread.`,
    `Spouse alignment isn't romantic. It's strategic. More marriages strain in year one of retirement than any other time.`,
    `Who are you without your job title? That's the question retirement planning should start with.`,
    `The anti-retirement movement is real. People in their 50s and 60s saying: I don't want to stop. I want to redesign.`,
    `Three years post-retirement and I finally figured out what the books got wrong. Let me save you the mistakes.`
  ];
  
  const posts = [];
  const now = new Date();
  
  for (let i = 0; i < count; i++) {
    const template = templates[i % templates.length];
    const scheduledDate = new Date(now);
    scheduledDate.setDate(scheduledDate.getDate() + i + 1);
    scheduledDate.setHours(9 + (i % 8), 0, 0, 0); // Spread through day
    
    posts.push({
      text: template,
      scheduled_at: scheduledDate.toISOString(),
      source: 'auto-generated'
    });
  }
  
  return posts;
}

/**
 * Format post for Buffer API
 */
function formatForBuffer(post) {
  return {
    text: post.text,
    scheduled_at: post.scheduled_at
  };
}

// CLI interface
if (require.main === module) {
  const args = process.argv.slice(2);
  const count = parseInt(args[0]) || 7;
  const topic = args[1] || 'The Anti-Retirement Guide';
  
  console.log(`Generating ${count} posts for "${topic}"...\n`);
  
  const posts = generateWeekOfPosts({ topic, count });
  
  posts.forEach((post, i) => {
    console.log(`Post ${i + 1}:`);
    console.log(`  Text: ${post.text.substring(0, 80)}...`);
    console.log(`  Scheduled: ${post.scheduled_at}`);
    console.log('');
  });
  
  console.log('To schedule these, use:');
  console.log('  node buffer.js schedule "post text" --time="ISO date"');
}

module.exports = { generateWeekOfPosts, formatForBuffer };
