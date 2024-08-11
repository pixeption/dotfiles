return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      omnisharp = {
        autostart = false,
        enable_roslyn_analyzers = true,
        organize_imports_on_format = true,
        enable_import_completion = true,
      },
    },
  },
}
