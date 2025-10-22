import { AbstractFileProviderService } from "@medusajs/framework/utils"
import {
  BlobServiceClient,
  ContainerClient,
  BlockBlobClient,
  BlobSASPermissions,
  StorageSharedKeyCredential
} from "@azure/storage-blob"
import type {
  Logger,
  ProviderUploadFileDTO,
  ProviderFileResultDTO,
  ProviderDeleteFileDTO,
  ProviderGetFileDTO
} from "@medusajs/framework/types"
import { Readable } from "stream"

type InjectedDependencies = {
  logger: Logger
}

export type AzureBlobOptions = {
  account_name: string
  account_key: string
  container_name: string
  prefix?: string
  cache_control?: string
  download_url_duration?: number
}

export class AzureBlobFileService extends AbstractFileProviderService {
  static identifier = "azure-blob"

  protected logger_: Logger
  protected options_: AzureBlobOptions
  protected blobServiceClient_: BlobServiceClient
  protected containerClient_: ContainerClient
  protected sharedKeyCredential_: StorageSharedKeyCredential

  constructor(
    { logger }: InjectedDependencies,
    options: AzureBlobOptions
  ) {
    super()

    this.logger_ = logger
    this.options_ = {
      cache_control: "public, max-age=31536000",
      download_url_duration: 3600,
      ...options,
    }

    this.sharedKeyCredential_ = new StorageSharedKeyCredential(
      this.options_.account_name,
      this.options_.account_key
    )

    const blobServiceUrl = `https://${this.options_.account_name}.blob.core.windows.net`

    this.blobServiceClient_ = new BlobServiceClient(
      blobServiceUrl,
      this.sharedKeyCredential_
    )

    this.containerClient_ = this.blobServiceClient_.getContainerClient(
      this.options_.container_name
    )
  }

  async upload(
    file: ProviderUploadFileDTO
  ): Promise<ProviderFileResultDTO> {
    const parsedFilename = this.parseFilename(file.filename)
    const fileKey = this.options_.prefix
      ? `${this.options_.prefix}/${parsedFilename}`
      : parsedFilename

    const blockBlobClient: BlockBlobClient =
      this.containerClient_.getBlockBlobClient(fileKey)

    try {
      if (Buffer.isBuffer(file.content)) {
        await blockBlobClient.upload(file.content, file.content.length, {
          blobHTTPHeaders: {
            blobContentType: file.mimeType,
            blobCacheControl: this.options_.cache_control,
          },
        })
      } else if (typeof (file.content as any)?.pipe === 'function') {
        await blockBlobClient.uploadStream(file.content as unknown as Readable, undefined, undefined, {
          blobHTTPHeaders: {
            blobContentType: file.mimeType,
            blobCacheControl: this.options_.cache_control,
          },
        })
      } else {
        const buffer = Buffer.from(file.content)
        await blockBlobClient.upload(buffer, buffer.length, {
          blobHTTPHeaders: {
            blobContentType: file.mimeType,
            blobCacheControl: this.options_.cache_control,
          },
        })
      }

      return {
        url: blockBlobClient.url,
        key: fileKey,
      }
    } catch (error) {
      this.logger_.error(
        `Error uploading file ${fileKey} to Azure Blob Storage: ${error.message}`
      )
      throw error
    }
  }

  async delete(
    files: ProviderDeleteFileDTO | ProviderDeleteFileDTO[]
  ): Promise<void> {
    const fileArray = Array.isArray(files) ? files : [files]

    try {
      await Promise.all(
        fileArray.map(async (file) => {
          const blockBlobClient = this.containerClient_.getBlockBlobClient(
            file.fileKey
          )
          await blockBlobClient.deleteIfExists()
        })
      )
    } catch (error) {
      this.logger_.error(
        `Error deleting files from Azure Blob Storage: ${error.message}`
      )
      throw error
    }
  }

  async getPresignedDownloadUrl(
    fileData: ProviderGetFileDTO
  ): Promise<string> {
    try {
      const blockBlobClient = this.containerClient_.getBlockBlobClient(
        fileData.fileKey
      )

      const permissions = new BlobSASPermissions()
      permissions.read = true

      const expiresOn = new Date()
      expiresOn.setSeconds(
        expiresOn.getSeconds() + (this.options_.download_url_duration || 3600)
      )

      const sasUrl = await blockBlobClient.generateSasUrl({
        permissions,
        expiresOn,
      })

      return sasUrl
    } catch (error) {
      this.logger_.error(
        `Error generating presigned URL for ${fileData.fileKey}: ${error.message}`
      )
      throw error
    }
  }

  async getAsStream(
    file: ProviderGetFileDTO
  ): Promise<Readable> {
    try {
      const blockBlobClient = this.containerClient_.getBlockBlobClient(
        file.fileKey
      )

      const downloadResponse = await blockBlobClient.download()

      if (!downloadResponse.readableStreamBody) {
        throw new Error(`Failed to get stream for file ${file.fileKey}`)
      }

      return downloadResponse.readableStreamBody as Readable
    } catch (error) {
      this.logger_.error(
        `Error getting stream for ${file.fileKey}: ${error.message}`
      )
      throw error
    }
  }

  async getAsBuffer(
    file: ProviderGetFileDTO
  ): Promise<Buffer> {
    try {
      const blockBlobClient = this.containerClient_.getBlockBlobClient(
        file.fileKey
      )

      const downloadResponse = await blockBlobClient.downloadToBuffer()

      return downloadResponse
    } catch (error) {
      this.logger_.error(
        `Error getting buffer for ${file.fileKey}: ${error.message}`
      )
      throw error
    }
  }

  protected parseFilename(filename: string): string {
    const parsed = filename.split(".")
    const extension = parsed.pop()
    const name = parsed.join(".")
    const timestamp = Date.now()

    return `${name}-${timestamp}.${extension}`
  }

  static validateOptions(options: Record<string, any>): void {
    if (!options.account_name) {
      throw new Error("Azure Blob Storage account_name is required")
    }
    if (!options.account_key) {
      throw new Error("Azure Blob Storage account_key is required")
    }
    if (!options.container_name) {
      throw new Error("Azure Blob Storage container_name is required")
    }
  }
}
