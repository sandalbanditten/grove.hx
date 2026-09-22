# TODO
- Use the same icons as `eza`
- Add a `?` keybind to list keybinds in the viewport
- Add a keybind to run `xdg-open` on a file

## Eza Style Rendering
Make the rendering more consistent with eza.
For example, this
```
  │ ▾  adapters     
  │ │ ▸  git        
  │ │ ▸  helix      
  │ │ · 󰘧 git.scm    
  │ │ · 󰘧 helix.scm  
  │ │ · 󰘧 scanner.scm
  │ ▸  domain       
```
should be
```
  ├─▾  adapters
  │   ├─▸  git
  │   ├── 󰘧 git.scm
  │   ├─▸  helix
  │   ├── 󰘧 helix.scm
  │   └── 󰘧 scanner.scm
  └─▸  domain
```
Note the completely alphabetical order, dirs not stacking at the top.
The alphabetical order should be available as a config toggle.


