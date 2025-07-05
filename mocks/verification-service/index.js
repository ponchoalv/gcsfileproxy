const express = require('express');
const app = express();
const port = 8080;

app.use(express.json());

app.post('/verify', (req, res) => {
  const { bucket, file } = req.body;
  console.log(`Verifying file: ${file} in bucket: ${bucket}`);
  // In this mock, we'll consider all files safe.
  res.json({ safe: true });
});

app.listen(port, () => {
  console.log(`Verification service listening at http://localhost:${port}`);
});
