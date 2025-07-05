import express from 'express';
import { downloadFile } from './routes';
import logger from './logger';

const app = express();
const port = process.env.PORT || 3000;

app.get('/download/:bucket/:file(*)', downloadFile);

app.get('/healthz', (req, res) => {
  res.status(200).send('OK');
});

app.listen(port, () => {
  logger.info(`Server is running on port ${port}`);
});
