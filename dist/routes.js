"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.downloadFile = void 0;
const storage_1 = require("@google-cloud/storage");
const axios_1 = __importDefault(require("axios"));
const logger_1 = __importDefault(require("./logger"));
const EMULATOR_HOST = process.env.STORAGE_EMULATOR_HOST;
const storage = new storage_1.Storage({
    apiEndpoint: EMULATOR_HOST ? `http://${EMULATOR_HOST}/storage/v1` : undefined,
    projectId: process.env.GOOGLE_CLOUD_PROJECT,
});
const VERIFICATION_SERVICE_URL = process.env.VERIFICATION_SERVICE_URL || 'http://localhost:8080/verify';
function isSafe(bucket, file) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            logger_1.default.info({ bucket, file }, `Verifying safety of gs://${bucket}/${file}`);
            const response = yield axios_1.default.post(VERIFICATION_SERVICE_URL, {
                bucket: bucket,
                file: file
            });
            logger_1.default.info({ bucket, file, safe: response.data.safe }, `Verification result for gs://${bucket}/${file}`);
            return response.data.safe;
        }
        catch (error) {
            logger_1.default.error({ bucket, file, error }, `Error verifying file safety for gs://${bucket}/${file}`);
            return false;
        }
    });
}
function downloadFile(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        const { bucket, file } = req.params;
        logger_1.default.info({ bucket, file }, `Received request for gs://${bucket}/${file}`);
        const safe = yield isSafe(bucket, file);
        if (!safe) {
            logger_1.default.warn({ bucket, file }, `File is not safe to download: gs://${bucket}/${file}`);
            res.status(403).send('File is not safe to download');
            return;
        }
        logger_1.default.info({ bucket, file }, `File is safe to download: gs://${bucket}/${file}`);
        try {
            const gcsFile = storage.bucket(bucket).file(file);
            logger_1.default.info({ bucket, file }, `Checking existence of gs://${bucket}/${file}`);
            const [exists] = yield gcsFile.exists();
            if (!exists) {
                logger_1.default.warn({ bucket, file }, `File not found: gs://${bucket}/${file}`);
                res.status(404).send('File not found');
                return;
            }
            logger_1.default.info({ bucket, file }, `File exists, starting download: gs://${bucket}/${file}`);
            res.setHeader('Content-disposition', `attachment; filename=${file}`);
            const stream = gcsFile.createReadStream();
            stream.pipe(res);
        }
        catch (error) {
            logger_1.default.error({ bucket, file, error }, 'Error downloading file');
            res.status(500).send('Internal Server Error');
        }
    });
}
exports.downloadFile = downloadFile;
