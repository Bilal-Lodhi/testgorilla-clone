const http = require('http');
const https = require('https');

const apiBaseUrl = process.env.API_BASE_URL || 'https://testgorilla-clone.onrender.com/api/v1';
const apiUrl = new URL(apiBaseUrl);
const client = apiUrl.protocol === 'https:' ? https : http;

const users = [
  {
    name: 'Admin User',
    email: 'admin@test.com',
    password: 'password',
    role: 'admin'
  },
  {
    name: 'Candidate User',
    email: 'candidate@test.com',
    password: 'password',
    role: 'candidate'
  },
  {
    name: 'Test Candidate',
    email: 'test2@example.com',
    password: '123456',
    role: 'candidate'
  }
];

async function registerUsers() {
  for (const user of users) {
    await registerUser(user);
  }
  console.log('✅ All users registered successfully!');
  process.exit(0);
}

function registerUser(userData) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(userData);

    const options = {
      hostname: apiUrl.hostname,
      port: apiUrl.port || (apiUrl.protocol === 'https:' ? 443 : 80),
      path: `${apiUrl.pathname.replace(/\/$/, '')}/auth/register`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length
      }
    };

    const req = client.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const response = JSON.parse(body);
          if (response.success) {
            console.log(`✅ Registered: ${userData.email}`);
            resolve();
          } else if (response.error?.message?.includes('already exists')) {
            console.log(`⚠️  Already exists: ${userData.email}`);
            resolve();
          } else {
            console.log(`❌ Failed: ${userData.email} - ${response.error?.message}`);
            resolve();
          }
        } catch (e) {
          console.log(`❌ Error registering ${userData.email}:`, body);
          resolve();
        }
      });
    });

    req.on('error', (err) => {
      console.error(`❌ Network error for ${userData.email}:`, err.message);
      resolve();
    });

    req.write(data);
    req.end();
  });
}

registerUsers().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
