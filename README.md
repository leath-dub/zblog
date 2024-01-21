# ZBLOG

This is a static site generator written in zig for my third year project for computer science at DCU. Due to time constraints both the source for the static site generator and my usage of it for the project are one in the same.

## Usage

```
zig build
```

This will build the site into a binary in `zig-out/bin/zblog`. You can run this which will run the site on port `:3000`

You can also just `zig build run`.

## Vars.zon

There is a specialized zon parser (if your interested `src/generator/vars_parser.zig`) that parses a `vars.zon` file that can specfies static files and variables for the site. E.g. you can have a simple `vars.zon`:

```zig
.{
    .title = "Blog",
}
```

This would allow you to reference the title in your files with `{{title}}`. Speaking of _your files_ you can
generically specify static files by creating special valued variables. A simple examle is of a `index.html` page.

```zig
...
    .@"index.html" = .{
        .type = .html,
        .path = "index.html",
        .hash_path = true,
    },
...
```

This will make "index.html" available at a _hashed_ (shake256 - 32 bytes) endpoint, though specifically a variable named `index.html` will be recognized by the backend and loaded at requests to `/`.

Another example is for a directory with many files, you can specify a blogs directory with markdown files like so:

```zig
...
    .blogs = .{
        .type = .markdown,
        .path = "my/path/blogs",
        .hash_path = true,
    },
...
```

This will all you to reference a list like so:

```html
{{#blogs}}
  <a href="{{& e}}">{{& e}}</a>
{{/blogs}}
```

(For what ever reason the mustache implementation in zap doesnt support the "." syntax so I had to wrap each blog
in a `.{ .e = ... }`, not ideal but functional)
