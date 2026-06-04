const sendEmail = async ({ to, subject, html }) => {
  try {
    const apiToken = process.env.ZENDESK_API_TOKEN || "X2y0UurUdpv72ya87RRpAeTGsO5h0g2dDm1L7rhc";
    const zendeskEmail = process.env.ZENDESK_EMAIL || "info@hexerve.com";
    const subdomain = process.env.ZENDESK_SUBDOMAIN || "hexerve";

    if (!apiToken || !zendeskEmail || !subdomain) {
      console.warn("Zendesk credentials missing, falling back to basic Nodemailer logging.");
      console.log(`[EMAIL MOCK] To: ${to}, Subject: ${subject}`);
      return { messageId: 'mock-' + Date.now() };
    }

    const url = `https://${subdomain}.zendesk.com/api/v2/tickets.json`;
    const authHeader = "Basic " + Buffer.from(`${zendeskEmail}/token:${apiToken}`).toString('base64');

    const ticketData = {
      ticket: {
        subject: subject,
        comment: {
          html_body: html // Zendesk uses html_body for HTML
        },
        requester: {
          name: "User",
          email: to
        }
      }
    };

    if (typeof fetch !== 'undefined') {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": authHeader
        },
        body: JSON.stringify(ticketData)
      });
      
      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`Zendesk API Error: ${response.status} ${errorText}`);
      }
      const data = await response.json();
      console.log('Message sent via Zendesk Ticket:', data.ticket?.id);
      return { messageId: 'zendesk-' + data.ticket?.id };
    } else {
      // Fallback for Node 16 (Render sometimes uses older Node)
      const https = require('https');
      const zendeskTicketId = await new Promise((resolve, reject) => {
        const reqOpts = new URL(url);
        const options = {
          hostname: reqOpts.hostname,
          path: reqOpts.pathname,
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': authHeader
          }
        };
        const reqHttp = https.request(options, (resHttp) => {
          let body = '';
          resHttp.on('data', chunk => body += chunk);
          resHttp.on('end', () => {
            if (resHttp.statusCode >= 200 && resHttp.statusCode < 300) {
              try {
                const data = JSON.parse(body);
                resolve(data.ticket?.id);
              } catch (e) { resolve(null); }
            } else {
              reject(new Error(`Zendesk API Error: ${resHttp.statusCode} ${body}`));
            }
          });
        });
        reqHttp.on('error', reject);
        reqHttp.write(JSON.stringify(ticketData));
        reqHttp.end();
      });
      console.log('Message sent via Zendesk Ticket (https):', zendeskTicketId);
      return { messageId: 'zendesk-' + zendeskTicketId };
    }
  } catch (error) {
    console.error('Error sending email:', error);
    throw error;
  }
};

module.exports = {
  sendEmail,
};
