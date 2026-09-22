# TODO
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
Note the completely alphabetical order, dirs not stacking at the top and the different rendering of the indicator lines.
The alphabetical order should be available as a config toggle.

## Other
- Add a `?` keybind to list keybinds in the viewport
- Add a keybind to run `xdg-open` on a file
- Minor differences in icons and color between eza and grove

