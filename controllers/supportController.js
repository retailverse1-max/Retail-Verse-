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

// GET /api/support/stats
exports.getSupportStats = async (req, res) => {
  try {
    const subdomain = process.env.ZENDESK_SUBDOMAIN;
    const zendeskEmail = process.env.ZENDESK_EMAIL;
    const apiToken = process.env.ZENDESK_API_TOKEN;

    if (!subdomain || !zendeskEmail || !apiToken) {
      return res.status(500).json({ success: false, message: "Support system not configured" });
    }

    const url = `https://${subdomain}.zendesk.com/api/v2/views/count.json?ids=360000000001`; // Replace with actual view ID or use search
    // For simplicity, we'll use search counts
    const authHeader = "Basic " + Buffer.from(`${zendeskEmail}/token:${apiToken}`).toString('base64');

    const fetchCount = async (query) => {
      const response = await fetch(`https://${subdomain}.zendesk.com/api/v2/search.json?query=${encodeURIComponent(query)}`, {
        headers: { "Authorization": authHeader }
      });
      const data = await response.json();
      return data.count || 0;
    };

    const [total, open, resolved, pending] = await Promise.all([
      fetchCount("type:ticket"),
      fetchCount("type:ticket status:open"),
      fetchCount("type:ticket status:solved"),
      fetchCount("type:ticket status:pending"),
    ]);

    res.status(200).json({
      success: true,
      data: { total, open, resolved, pending }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};

// GET /api/support/tickets
exports.getRecentTickets = async (req, res) => {
  try {
    const subdomain = process.env.ZENDESK_SUBDOMAIN;
    const zendeskEmail = process.env.ZENDESK_EMAIL;
    const apiToken = process.env.ZENDESK_API_TOKEN;

    const url = `https://${subdomain}.zendesk.com/api/v2/tickets.json?sort_by=created_at&sort_order=desc&per_page=10`;
    const authHeader = "Basic " + Buffer.from(`${zendeskEmail}/token:${apiToken}`).toString('base64');

    const response = await fetch(url, {
      headers: { "Authorization": authHeader }
    });
    const data = await response.json();

    res.status(200).json({
      success: true,
      tickets: data.tickets || []
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
};
