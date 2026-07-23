import from .ui.button { buttonVariants }
import from "..lib.utils" { cn }
import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    GithubIcon, Moon01Icon, Sun01Icon, Menu01Icon, Cancel01Icon, ArrowRight01Icon
}

glob _LINKS: list[dict] = [
    {"label": "Why Jac", "href": "/#why"},
    {"label": "Language", "href": "/#language"},
    {"label": "Build", "href": "/#build"},
    {"label": "Agents", "href": "/#agents"},
    {"label": "Research", "href": "/#research"},
];

def:pub Navbar() -> JsxElement {
    has dark: bool = True;
    has menu_open: bool = False;

    can with entry {
        dark = document.documentElement.classList.contains("dark");
    }

    def toggle_theme(_e: MouseEvent) {
        if dark {
            document.documentElement.classList.remove("dark");
            localStorage.setItem("jac-theme", "light");
            dark = False;
        } else {
            document.documentElement.classList.add("dark");
            localStorage.setItem("jac-theme", "dark");
            dark = True;
        }
    }

    def toggle_menu(_e: MouseEvent) {
        menu_open = not menu_open;
    }

    def close_menu(_e: MouseEvent) {
        menu_open = False;
    }

    return <header className="fixed inset-x-0 top-0 z-50 border-b border-border/60 bg-background/75 backdrop-blur-xl">
        <div className="mx-auto flex h-16 max-w-7xl items-center gap-6 pl-4 pr-4 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
            <Link to="/" className="flex items-center gap-2.5">
                <img src="/static/assets/jac-logo.png" alt="Jac logo" className="size-8" />
                <span className="text-lg font-bold tracking-tight">Jac</span>
            </Link>
            <nav className="hidden items-center gap-1 lg:flex">
                {for (i, lk) in enumerate(_LINKS) {
                    <a key={str(i)} href={lk["href"]}
                        className="rounded-md pl-3 pr-3 pt-1.5 pb-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground">
                        {lk["label"]}
                    </a>
                }}
            </nav>
            <div className="ml-auto flex items-center gap-2">
                <Link to="/docs/latest"
                    className="hidden rounded-md pl-3 pr-3 pt-1.5 pb-1.5 text-sm text-muted-foreground transition-colors hover:bg-accent hover:text-foreground sm:block">
                    Docs
                </Link>
                <button onClick={toggle_theme} title="Toggle theme"
                    className={buttonVariants().call(None, {"variant": "ghost", "size": "icon"})}>
                    {if dark {
                        <HugeiconsIcon icon={Sun01Icon} strokeWidth={2} className="size-4" />
                    } else {
                        <HugeiconsIcon icon={Moon01Icon} strokeWidth={2} className="size-4" />
                    }}
                </button>
                <a href="https://github.com/jaseci-labs/jaseci" target="_blank" rel="noreferrer" title="GitHub"
                    className={buttonVariants().call(None, {"variant": "ghost", "size": "icon"})}>
                    <HugeiconsIcon icon={GithubIcon} strokeWidth={2} className="size-4" />
                </a>
                <a href="/#get-started" className={cn(buttonVariants().call(None, {"size": "sm"}), "hidden sm:inline-flex")}>
                    Get started
                    <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="size-4" />
                </a>
                <button onClick={toggle_menu} title="Menu"
                    className={cn(buttonVariants().call(None, {"variant": "ghost", "size": "icon"}), "lg:hidden")}>
                    {if menu_open {
                        <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} className="size-4" />
                    } else {
                        <HugeiconsIcon icon={Menu01Icon} strokeWidth={2} className="size-4" />
                    }}
                </button>
            </div>
        </div>
        {if menu_open {
            <nav className="border-t border-border/60 bg-background/95 backdrop-blur-xl lg:hidden">
                <div className="mx-auto flex max-w-7xl flex-col gap-1 pl-4 pr-4 pt-3 pb-4">
                    {for (i, lk) in enumerate(_LINKS) {
                        <a key={str(i)} href={lk["href"]} onClick={close_menu}
                            className="rounded-md pl-3 pr-3 pt-2 pb-2 text-sm text-muted-foreground hover:bg-accent hover:text-foreground">
                            {lk["label"]}
                        </a>
                    }}
                    <Link to="/docs/latest" onClick={close_menu}
                        className="rounded-md pl-3 pr-3 pt-2 pb-2 text-sm text-muted-foreground hover:bg-accent hover:text-foreground">
                        Docs
                    </Link>
                </div>
            </nav>
        }}
    </header>;
}
