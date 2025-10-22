import { ModuleProvider, Modules } from "@medusajs/framework/utils"
import { AzureBlobFileService } from "./service"

export default ModuleProvider(Modules.FILE, {
  services: [AzureBlobFileService],
})
