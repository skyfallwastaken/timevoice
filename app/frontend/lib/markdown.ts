import MarkdownIt from "markdown-it";

// Mirrors InvoicePdf's Commonmarker setup so the preview matches the printed invoice:
// raw HTML stays literal text, newlines are line breaks, no tables, images show their
// alt text, and only http(s)/mailto links are linked.
const SAFE_LINK = /^(https?:|mailto:)/i;

const md = new MarkdownIt({ html: false, linkify: true, breaks: true }).disable(
  "table",
);

md.validateLink = () => true;
md.renderer.rules.image = (tokens, idx) =>
  md.utils.escapeHtml(tokens[idx].content);
md.renderer.rules.link_open = (tokens, idx, options, _env, self) => {
  const token = tokens[idx];
  if (SAFE_LINK.test(token.attrGet("href") ?? "")) {
    token.attrSet("target", "_blank");
    token.attrSet("rel", "noopener noreferrer");
  } else {
    const close = tokens.findIndex(
      (t, i) => i > idx && t.type === "link_close" && t.level === token.level,
    );
    token.tag = tokens[close].tag = "span";
    token.attrs = null;
  }
  return self.renderToken(tokens, idx, options);
};

export function renderMarkdown(source: string): string {
  return md.render(source);
}
