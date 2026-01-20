/**
 * Service S3 / Wasabi pour le stockage des fichiers
 */
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const config = require("../config");
const path = require("path");

class S3Service {
    constructor() {
        // Initialisation du client S3 (compatible Wasabi)
        this.s3Client = new S3Client({
            region: config.S3_REGION,
            endpoint: config.S3_ENDPOINT,
            credentials: {
                accessKeyId: config.AWS_ACCESS_KEY_ID,
                secretAccessKey: config.AWS_SECRET_ACCESS_KEY
            },
            forcePathStyle: true // Nécessaire pour certains providers alternatifs comme MinIO ou certains configs Wasabi
        });
    }

    /**
     * Upload un fichier sur S3/Wasabi
     * @param {Buffer} fileBuffer - Le contenu du fichier
     * @param {string} originalName - Nom original du fichier
     * @param {string} mimeType - Type MIME
     * @param {string} folder - Dossier de destination (ex: "chat", "products")
     * @returns {Promise<string>} - URL du fichier uploadé
     */
    async uploadFile(fileBuffer, originalName, mimeType, folder = "uploads") {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const extension = path.extname(originalName);
        const fileName = `${folder}/${uniqueSuffix}${extension}`;

        const params = {
            Bucket: config.S3_BUCKET,
            Key: fileName,
            Body: fileBuffer,
            ContentType: mimeType,
            ACL: 'public-read' // Assurez-vous que le bucket permet les ACLs publics ou utilisez des presigned URLs
        };

        try {
            const command = new PutObjectCommand(params);
            await this.s3Client.send(command);

            // Construction de l'URL publique (Format standard Wasabi/S3)
            // Note: Si vous utilisez un CDN ou un domaine personnalisé, ajustez ici
            // Format S3/Wasabi habituel: https://endpoint/bucket/key ou https://bucket.endpoint/key

            // On utilise le format path-style s'il est forcé, sinon virtual-host style.
            // Pour simplifier ici on construit une URL générique basée sur l'endpoint.

            // Nettoyage de l'endpoint pour éviter les doubles slashs
            const cleanEndpoint = config.S3_ENDPOINT.replace(/\/$/, "");

            return `${cleanEndpoint}/${config.S3_BUCKET}/${fileName}`;
        } catch (error) {
            console.error("❌ ERREUR S3 Upload:", error);
            throw new Error("Erreur lors de l'upload du fichier");
        }
    }
}

module.exports = new S3Service();
