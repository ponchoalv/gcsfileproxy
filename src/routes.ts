import { Request, Response } from 'express';
import { Storage } from '@google-cloud/storage';
import axios from 'axios';
import logger from './logger';

const GCS_EMULATOR_ENDPOINT = process.env.GCS_EMULATOR_ENDPOINT;
const storage = new Storage({
  projectId: process.env.GOOGLE_CLOUD_PROJECT,
  // Use explicit API endpoint for the emulator
  apiEndpoint: GCS_EMULATOR_ENDPOINT ? `${GCS_EMULATOR_ENDPOINT}` : undefined,
  keyFilename: GCS_EMULATOR_ENDPOINT ? undefined : undefined, // Disable auth for emulator
});

const VERIFICATION_SERVICE_URL = process.env.VERIFICATION_SERVICE_URL || 'http://localhost:8080/verify';

async function isSafe(bucket: string, file: string): Promise<boolean> {
    try {
        logger.info({ bucket, file }, `Verifying safety of gs://${bucket}/${file}`);
        const response = await axios.post(VERIFICATION_SERVICE_URL, {
            bucket: bucket,
            file: file
        });
        logger.info({ bucket, file, safe: response.data.safe }, `Verification result for gs://${bucket}/${file}`);
        return response.data.safe;
    } catch (error) {
        logger.error({ bucket, file, error }, `Error verifying file safety for gs://${bucket}/${file}`);
        return false;
    }
}

export async function downloadFile(req: Request, res: Response) {
  const { bucket, file } = req.params;
  logger.info({ bucket, file }, `Received request for gs://${bucket}/${file}`);

  const safe = await isSafe(bucket, file);
  if (!safe) {
    logger.warn({ bucket, file }, `File is not safe to download: gs://${bucket}/${file}`);
    res.status(403).send('File is not safe to download');
    return;
  }
  logger.info({ bucket, file }, `File is safe to download: gs://${bucket}/${file}`);

  try {
    const gcsFile = storage.bucket(bucket).file(file);
    logger.info({ bucket, file }, `Checking existence of gs://${bucket}/${file}`);
    const [exists] = await gcsFile.exists();

    if (!exists) {
      logger.warn({ bucket, file }, `File not found: gs://${bucket}/${file}`);
      res.status(404).send('File not found');
      return;
    }
    logger.info({ bucket, file }, `File exists, starting download: gs://${bucket}/${file}`);

    res.setHeader('Content-disposition', `attachment; filename=${file}`);
    const stream = gcsFile.createReadStream();
    stream.pipe(res);
  } catch (error) {
    logger.error({ bucket, file, error }, 'Error downloading file');
    res.status(500).send('Internal Server Error');
  }
}
