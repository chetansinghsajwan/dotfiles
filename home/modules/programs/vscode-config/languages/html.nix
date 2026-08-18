{ ... }:
{
  programs.vscode.userSettings = {
    # Enable/disable autoclosing of HTML tags.
    html.autoClosingTags = true;

    # Enable/disable auto creation of quotes for HTML attribute assignment. The type of quotes can be configured by `html.completion.attributeDefaultValue`.
    html.autoCreateQuotes = true;

    # Controls the default value for attributes when completion is accepted.
    #  - doublequotes: Attribute value is set to "".
    #  - singlequotes: Attribute value is set to ''.
    #  - empty: Attribute value is not set.
    html.completion.attributeDefaultValue = "doublequotes";

    # A list of relative file paths pointing to JSON files following the custom data format.
    # VS Code loads custom data on startup to enhance its HTML support for the custom HTML tags, attributes and attribute values you specify in the JSON files.
    # The file paths are relative to workspace and only workspace folder settings are considered.
    html.customData = [ ];

    # List of tags, comma separated, where the content shouldn't be reformatted. `null` defaults to the `pre` tag.
    html.format.contentUnformatted = "pre,code,textarea";

    # Enable/disable default HTML formatter.
    html.format.enable = true;

    # List of tags, comma separated, that should have an extra newline before them. `null` defaults to `"head, body, /html"`.
    html.format.extraLiners = "head, body, /html";

    # Format and indent ``.
    html.format.indentHandlebars = false;

    # Indent `<head>` and `<body>` sections.
    html.format.indentInnerHtml = false;

    # Maximum number of line breaks to be preserved in one chunk. Use `null` for unlimited.
    html.format.maxPreserveNewLines = null;

    # Controls whether existing line breaks before elements should be preserved. Only works before elements, not inside tags or for text.
    html.format.preserveNewLines = true;

    # Honor django, erb, handlebars and php templating language tags.
    html.format.templating = false;

    # List of tags, comma separated, that shouldn't be reformatted.
    html.format.unformatted = "wbr";

    # Keep text content together between this string.
    html.format.unformattedContentDelimiter = "";

    # Wrap attributes.
    #  - auto: Wrap attributes only when line length is exceeded.
    #  - force: Wrap each attribute except first.
    #  - force-aligned: Wrap each attribute except first and keep aligned.
    #  - force-expand-multiline: Wrap each attribute.
    #  - aligned-multiple: Wrap when line length is exceeded, align attributes vertically.
    #  - preserve: Preserve wrapping of attributes.
    #  - preserve-aligned: Preserve wrapping of attributes but align.
    html.format.wrapAttributes = "auto";

    # Indent wrapped attributes to after N characters. Use `null` to use the default indent size. Ignored if `html.format.wrapAttributes` is set to `aligned`.
    html.format.wrapAttributesIndentSize = null;

    # Maximum amount of characters per line (0 = disable).
    html.format.wrapLineLength = 120;

    # Show tag and attribute documentation in hover.
    html.hover.documentation = true;

    # Show references to MDN in hover.
    html.hover.references = true;

    # Controls whether the built-in HTML language support suggests HTML5 tags, properties and values.
    html.suggest.html5 = true;

    # Traces the communication between VS Code and the HTML language server.
    html.trace.server = "off";

    # Controls whether the built-in HTML language support validates embedded scripts.
    html.validate.scripts = true;

    # Controls whether the built-in HTML language support validates embedded styles.
    html.validate.styles = true;
  };
}
