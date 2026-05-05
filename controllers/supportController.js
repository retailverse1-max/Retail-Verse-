// POST /api/support/ticket
exports.createTicket = async (req, res) => {
  try {
    const { subject, message, userName, email, role, businessName, storeId } = req.body;

    if (!subject || !message) {
      return res.status(400).json({ success: false, message: "Subject and message are required" });
    }

    const subdomain = process.env.ZENDESK_SUBDOMAIN;
    const zendeskEmail = process.env.ZENDESK_EMAIL;
    const apiToken = process.env.ZENDESK_API_TOKEN;

    if (!subdomain || !zendeskEmail || !apiToken) {
      return res.status(500).json({ 
        success: false, 
        message: "Support system is not configured on the server. Please contact administrator." 
      });
    }

    const url = `https://${subdomain}.zendesk.com/api/v2/tickets.json`;
    const authHeader = "Basic " + Buffer.from(`${zendeskEmail}/token:${apiToken}`).toString('base64');

    const ticketData = {
      ticket: {
        subject: subject,
        comment: {
          body: `
User Name: ${userName || 'N/A'}
Email: ${email || 'N/A'}
Role: ${role || 'N/A'}
Business: ${businessName || 'N/A'}
Store ID: ${storeId || 'N/A'}

Message:
${message}
          `.trim()
        },
        requester: {
          name: userName || "Retail Verse User",
          email: email || zendeskEmail
        }
      }
    };

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": authHeader
      },
      body: JSON.stringify(ticketData)
    });

    const data = await response.json();

    if (!response.ok) {
      console.error("Zendesk API error:", data);
      return res.status(response.status).json({ success: false, message: "Failed to create support ticket", error: data });
    }

    res.status(200).json({
      success: true,
      message: "Support ticket created successfully",
      ticketId: data.ticket?.id
    });
  } catch (error) {
    console.error("Error creating support ticket:", error);
    res.status(500).json({ success: false, message: "Server Error", error: error.message });
  }
};
