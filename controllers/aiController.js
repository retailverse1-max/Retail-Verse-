const { GoogleGenerativeAI } = require("@google/generative-ai");

exports.scanProductImage = async (req, res) => {
  try {
    const apiKey = process.env.GEMINI_API_KEY;

    // Check if AI is configured
    if (!apiKey || apiKey === "YOUR_GEMINI_KEY_HERE" || apiKey.trim() === "") {
      return res.status(503).json({
        success: false,
        message: "AI service not configured. Missing GEMINI_API_KEY.",
      });
    }

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "No image file provided.",
      });
    }

    // Initialize Gemini
    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

    const mimeType = req.file.mimetype;
    const imagePart = {
      inlineData: {
        data: req.file.buffer.toString("base64"),
        mimeType: mimeType,
      },
    };

    const prompt = `
You are an expert retail and inventory AI assistant. Analyze this product image.
Please return your response STRICTLY as a valid JSON object without any markdown formatting, code blocks, or extra text.

The JSON MUST contain the following keys exactly:
{
  "name": "A clear, concise, and professional product name",
  "category": "The best fitting retail category (e.g., Electronics, Groceries, Tools, Apparel)",
  "description": "A detailed, professional description suitable for an e-commerce or POS system",
  "tags": ["array", "of", "relevant", "search", "keywords"],
  "confidence": <a number between 0.0 and 1.0 representing how confident you are in this analysis>
}`;

    const result = await model.generateContent([prompt, imagePart]);
    const responseText = result.response.text();

    // Clean up potential markdown formatting from Gemini
    let cleanText = responseText.trim();
    if (cleanText.startsWith("```json")) {
      cleanText = cleanText.replace(/```json/g, "").replace(/```/g, "").trim();
    } else if (cleanText.startsWith("```")) {
      cleanText = cleanText.replace(/```/g, "").trim();
    }

    let parsedJson;
    try {
      parsedJson = JSON.parse(cleanText);
    } catch (parseError) {
      console.error("Failed to parse Gemini response as JSON:", cleanText);
      return res.status(500).json({
        success: false,
        message: "AI returned an invalid response format.",
      });
    }

    return res.status(200).json({
      success: true,
      data: parsedJson,
    });
  } catch (error) {
    console.error("AI Scan Error:", error);
    
    // Handle specific Gemini API errors
    if (error.message && error.message.includes("quota")) {
      return res.status(429).json({
        success: false,
        message: "AI rate limit exceeded. Please try again later.",
      });
    }

    return res.status(500).json({
      success: false,
      message: "An error occurred while communicating with the AI service.",
    });
  }
};
