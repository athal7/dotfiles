# Overview
Format your elixir code automatically using `mix format`, by simply installing this extension and configuring it to be
the default formatter for `elixir`, if it is not already chosen by default.
If the `editor.formatOnSave` setting in Visual Studio Code is set, then the elixir file that is being edited will be formatted automatically on saving.

## Configuration
By default, this extension runs `mix format` using the workspace root directory as the working directory. The following
options are available for the user to configure, in `settings.json`:

```javascript
{
  elixir.formatter: {
    mixFormatArgs: "--dry-run",
    formatterCwd: "../some/dir/to/run/mix/format/from"
  }
}
```

## Requirements
* Install Elixir 1.6

## License
MIT
