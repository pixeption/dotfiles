return {
  "knubie/vim-kitty-navigator",
  enabled = true,
  keys = {
    {
      "<C-h>",
      "<cmd>KittyNavigateLeft<cr>",
      desc = "Navigate window left",
    },
    {
      "<C-j>",
      "<cmd>KittyNavigateDown<cr>",
      desc = "Navigate window down",
    },
    {
      "<C-k>",
      "<cmd>KittyNavigateUp<cr>",
      desc = "Navigate window up",
    },
    {
      "<C-l>",
      "<cmd>KittyNavigateRight<cr>",
      desc = "Navigate window right",
    },
  },
}
