"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const routes_1 = require("./routes");
const logger_1 = __importDefault(require("./logger"));
const app = (0, express_1.default)();
const port = process.env.PORT || 3000;
app.get('/download/:bucket/:file(*)', routes_1.downloadFile);
app.get('/healthz', (req, res) => {
    res.status(200).send('OK');
});
app.listen(port, () => {
    logger_1.default.info(`Server is running on port ${port}`);
});
