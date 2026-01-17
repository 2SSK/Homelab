" ==================================================
" PRODUCTION VIMRC (SERVER SAFE)
" ==================================================

" --- Core safety ---
set nocompatible
set encoding=utf-8
set fileencoding=utf-8
set hidden
set autoread

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

" --- Files & backups (safe defaults) ---
set nobackup
set nowritebackup
set noswapfile
set undofile
set undodir=~/.vim/undo//

" --- Completion ---
set completeopt=menuone,noselect
set pumheight=10
set shortmess+=c

" --- Performance ---
set updatetime=300
set timeoutlen=300
set lazyredraw

" --- Splits ---
set splitbelow
set splitright

" --- Clipboard (works when available) ---
set clipboard=unnamedplus

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

" Save without autocommands
nnoremap <leader>sn :noautocmd w<CR>

" Delete without yank
nnoremap x "_x

" Centered scrolling
nnoremap <C-d> <C-d>zz
nnoremap <C-u> <C-u>zz

" Center search results
nnoremap n nzzzv
nnoremap N Nzzzv

" Buffers
nnoremap <Tab> :bnext<CR>
nnoremap <S-Tab> :bprevious<CR>
nnoremap <leader>x :bdelete<CR>
nnoremap <leader>b :enew<CR>

" Windows
nnoremap <leader>sv <C-w>v
nnoremap <leader>sh <C-w>s
nnoremap <leader>se <C-w>=
nnoremap <leader>sx :close<CR>

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Tabs
nnoremap <leader>to :tabnew<CR>
nnoremap <leader>tx :tabclose<CR>
nnoremap <leader>tn :tabn<CR>
nnoremap <leader>tp :tabp<CR>

" Insert mode escape
inoremap jk <Esc>

" Paste without clobbering register
vnoremap p "_dP

" Explicit clipboard yank
nnoremap <leader>y "+y
nnoremap <leader>Y "+Y

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
augroup END

nnoremap <leader>e :Lexplore<CR>

" ==================================================
" Syntax & colors (safe)
" ==================================================

syntax on
set background=dark
colorscheme wildcharm
set termguicolors
