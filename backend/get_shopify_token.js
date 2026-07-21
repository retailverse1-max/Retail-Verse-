const express = require('express');
const axios = require('axios');
const app = express();

const API_KEY = '4d83b8671f93d2c67c1ca7abe6723777';
const API_SECRET = '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';

app.get('/callback', async (req, res) => {
    const { shop, code } = req.query;
    
    if (!shop || !code) {
        return res.send('Missing shop or code parameter.');
    }

    try {
        const response = await axios.post(`https://${shop}/admin/oauth/access_token`, {
            client_id: API_KEY,
            client_secret: API_SECRET,
            code: code
        });

        const accessToken = response.data.access_token;
        console.log('\n\n================================================');
        console.log('🎉 SUCCESS! HERE IS YOUR ACCESS TOKEN:');
        console.log(accessToken);
        console.log('================================================\n\n');
        
        res.send(`<h1>Success!</h1><p>Your access token is: <b>${accessToken}</b></p><p>You can close this window and put this token in your Retail Verse app.</p>`);
        
        // Stop the server after getting the token
        setTimeout(() => process.exit(0), 1000);
    } catch (error) {
        console.error('Error fetching access token:', error.response ? error.response.data : error.message);
        res.send('Error fetching access token. Check the terminal.');
    }
});

app.listen(3005, () => {
    console.log('Server is running on http://localhost:3005');
    console.log('Waiting for Shopify OAuth callback...');
});
