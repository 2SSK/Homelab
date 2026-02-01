" ==================================================
" PRODUCTION VIMRC (SERVER SAFE)
" Managed by GNU Stow from /opt/Homelab/dotfiles
" ==================================================

" --- Core safety ---
set nocompatible
set encoding=utf-8
set fileencoding=utf-8
set hidden
set autoread

" Automatically reload files changed outside of vim
autocmd FocusGained,BufEnter * checktime

" --- UI (minimal, SSH safe) ---
set number
set relativenumber
set numberwidth=2
set signcolumn=yes
set laststatus=2
set showmatch
set ruler
set nowrap
set scrolloff=5
set sidescrolloff=5
set mouse=a
set cursorline

" --- Command line ---
set showcmd
set cmdheight=1
set wildmenu
set wildmode=longest:full,full
set wildignore+=*.pyc,*.o,*.obj,*.swp,*.class,*.DS_Store,*.git

" --- Search ---
set ignorecase
set smartcase
set incsearch
set nohlsearch

" --- Indentation ---
set expandtab
set shiftwidth=2
set tabstop=2
set softtabstop=2
set smartindent
set autoindent
set shiftround

" --- Files & backups (safe defaults) ---
set nobackup
set nowritebackup
set noswapfile
set undofile
set undodir=~/.vim/undo//

" Create undo directory if it doesn't exist
if !isdirectory(expand('~/.vim/undo'))
    call mkdir(expand('~/.vim/undo'), 'p', 0700)
endif

" --- Completion ---
set completeopt=menuone,noselect
set pumheight=10
set shortmess+=c

" --- Performance ---
set updatetime=300
set timeoutlen=300
set lazyredraw
set ttyfast

" --- Splits ---
set splitbelow
set splitright

" --- Clipboard (works when available) ---
if has('clipboard')
    set clipboard=unnamedplus
endif

" --- Visual feedback ---
set belloff=all
set confirm
set title

" ==================================================
" Key mappings (conservative)
" ==================================================

let mapleader=" "
let maplocalleader=" "

nnoremap <Space> <Nop>
vnoremap <Space> <Nop>

" Wrapped line navigation
nnoremap <expr> j v:count == 0 ? 'gj' : 'j'
nnoremap <expr> k v:count == 0 ? 'gk' : 'k'

" Clear search highlight
nnoremap <leader>nh :noh<CR>

" Save / Quit
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>Q :qa!<CR>

" Save without autocommands
nnoremap <leader>sn :noautocmd w<CR>

" Delete without yank
nnoremap x "_x
nnoremap X "_X

" Centered scrolling
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz

" Center search results
nnoremap n nzzzv
nnoremap N Nzzzv

" Join lines without moving cursor
nnoremap J mzJ`z

" Buffers
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprevious<CR>
nnoremap <leader>x :bdelete<CR>
nnoremap <leader>b :enew<CR>
nnoremap <leader>ba :bufdo bd<CR>

" Windows
nnoremap <leader>sv <C-w>v
nnoremap <leader>sh <C-w>s
nnoremap <leader>se <C-w>=
nnoremap <leader>sx :close<CR>

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Resize windows
nnoremap <C-Up> :resize +2<CR>
nnoremap <C-Down> :resize -2<CR>
nnoremap <C-Left> :vertical resize -2<CR>
nnoremap <C-Right> :vertical resize +2<CR>

" Tabs
nnoremap <leader>to :tabnew<CR>
nnoremap <leader>tx :tabclose<CR>
nnoremap <leader>tn :tabn<CR>
nnoremap <leader>tp :tabp<CR>

" Insert mode escape
inoremap jk <Esc>

" Stay in visual mode when indenting
vnoremap < <gv
vnoremap > >gv

" Move lines in visual mode
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

" Paste without clobbering register
vnoremap p "_dP

" Explicit clipboard yank
nnoremap <leader>y "+y
vnoremap <leader>y "+y
nnoremap <leader>Y "+Y

" Quick find and replace
nnoremap <leader>r :%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>

" ==================================================
" Netrw (built-in file explorer)
" ==================================================

let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_browse_split = 4
let g:netrw_altv = 1
let g:netrw_winsize = 25

augroup netrw_setup
  autocmd!
  autocmd FileType netrw nnoremap <buffer> l <CR>
  autocmd FileType netrw nnoremap <buffer> h -
augroup END

nnoremap <leader>e :Lexplore<CR>
nnoremap <leader>E :Explore<CR>

" ==================================================
" File type specific settings
" ==================================================

augroup filetypes
  autocmd!
  " Makefile needs tabs
  autocmd FileType make setlocal noexpandtab tabstop=4 shiftwidth=4
  " Python
  autocmd FileType python setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
  " YAML
  autocmd FileType yaml setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2
  " Shell scripts
  autocmd FileType sh,bash setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
  " Markdown
  autocmd FileType markdown setlocal wrap linebreak spell
  " Git commit
  autocmd FileType gitcommit setlocal spell textwidth=72
augroup END

" ==================================================
" Status line (minimal, no plugins)
" ==================================================

set statusline=
set statusline+=%#PmenuSel#
set statusline+=\ %{mode()}\ 
set statusline+=%#LineNr#
set statusline+=\ %f
set statusline+=%m
set statusline+=%r
set statusline+=%=
set statusline+=%#CursorColumn#
set statusline+=\ %y
set statusline+=\ %{&fileencoding?&fileencoding:&encoding}
set statusline+=\ [%{&fileformat}]
set statusline+=\ %p%%
set statusline+=\ %l:%c
set statusline+=\ 

" ==================================================
" Syntax & colors (safe)
" ==================================================

syntax on
set background=dark

" Use colorscheme if available
try
    colorscheme wildcharm
catch
    " Fallback to default
endtry

" Terminal color support
if has('termguicolors')
    set termguicolors
endif

" ==============================
" Transparent Background
" ==============================
highlight Normal ctermbg=NONE guibg=NONE
highlight NonText ctermbg=NONE guibg=NONE
highlight LineNr ctermbg=NONE guibg=NONE
highlight SignColumn ctermbg=NONE guibg=NONE
highlight VertSplit ctermbg=NONE guibg=NONE
highlight StatusLine ctermbg=NONE guibg=NONE
highlight EndOfBuffer ctermbg=NONE guibg=NONE

" Reapply transparency after colorscheme loads
autocmd ColorScheme * highlight Normal ctermbg=NONE guibg=NONE

" ==================================================
" Quick commands
" ==================================================

" Trim trailing whitespace
command! TrimWhitespace :%s/\s\+$//e

" Reload vimrc
command! ReloadVimrc source $MYVIMRC

" Insert date/time
command! InsertDate :normal a<C-R>=strftime('%Y-%m-%d')<CR>
command! InsertDateTime :normal a<C-R>=strftime('%Y-%m-%d %H:%M:%S')<CR>
