
a fuzzy finder for nvim based on fzf

## design
* i dont use coroutines
* query placeholder
* two version of sources: cache and non-cache
* caching in files under /tmp
* single/batch entries handling
* actions, `<c-*>` are mutual exclusive between single and batch handling, rather than the choices's number

## sources
* files: `fd --type f`
* git files: `git ls-files`
* git modified files: `git ls-files --modified`
* git status files: git status
* ~~buffers~~
* ~~mru~~
* olds # haolian9/olds.nvim
* sibling files `fd --type f getcwd()`
* lsp document symbols
* lsp workspace symbols
* ~~windows: similar to `tmux join-pane`~~
* ctags of a file
* ~~arglist~~

## status
* just-works
* not supposed to be used publiclly

## prerequisites
* linux
* nvim 0.10.*
* haolian9/infra.nvim
* haolian9/sting.nvim
* haolian9/fzf # fork of junegunn's, for query placeholder and `--input/output` cli flag

optional
* fd
* git
* haolian9/olds.nvim
* lsp
* ctags

## usage

my personal config
```
do
  m.n("<leader>s", function() require("fond").files() end)
  m.n("<leader>g", function() require("fond").tracked() end)
  m.n("<leader>u", function() require("fond").statuses() end)
  m.n("<leader>m", function() require("fond").olds() end)
  m.n("<leader>f", function() require("fond").siblings() end)
  m.n("<leader>d", function() require("fond").document_symbols() end)
  --no-cache version
  m.n("<leader>S", function() require("fond").files(false) end)
  m.n("<leader>G", function() require("fond").tracked(false) end)
  m.n("<leader>M", function() require("fond").olds(false) end)
  m.n("<leader>F", function() require("fond").siblings(false) end)
  m.n("<leader>D", function() require("fond").document_symbols(false) end)

  do
    local spell = cmds.Spell("Fond", function(args) assert(require("fond")[args.provider])(args.fresh) end)
    spell:add_arg("provider", "string", true, nil, cmds.ArgComp.constant({ "workspace_symbols", "ctags" }))
    spell:add_flag("fresh", "true", false)
    cmds.cast(spell)
  end
end
```
