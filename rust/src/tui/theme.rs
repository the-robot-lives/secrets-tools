use ratatui::style::{Color, Modifier, Style};

pub struct Theme;

impl Theme {
    // <REMOVED UUID HERE> ok :: auto-generated pointer for public function ok
    pub fn ok() -> Style {
        Style::default().fg(Color::Green)
    }
    // <REMOVED UUID HERE> error :: auto-generated pointer for public function error
    pub fn error() -> Style {
        Style::default().fg(Color::Red)
    }
    // <REMOVED UUID HERE> warn :: auto-generated pointer for public function warn
    pub fn warn() -> Style {
        Style::default().fg(Color::Yellow)
    }
    // <REMOVED UUID HERE> info :: auto-generated pointer for public function info
    pub fn info() -> Style {
        Style::default().fg(Color::Cyan)
    }
    // <REMOVED UUID HERE> muted :: auto-generated pointer for public function muted
    pub fn muted() -> Style {
        Style::default().fg(Color::DarkGray)
    }
    // <REMOVED UUID HERE> header :: auto-generated pointer for public function header
    pub fn header() -> Style {
        Style::default()
            .fg(Color::White)
            .add_modifier(Modifier::BOLD)
    }
    // <REMOVED UUID HERE> selected :: auto-generated pointer for public function selected
    pub fn selected() -> Style {
        Style::default()
            .fg(Color::Black)
            .bg(Color::Cyan)
            .add_modifier(Modifier::BOLD)
    }
    // <REMOVED UUID HERE> title :: auto-generated pointer for public function title
    pub fn title() -> Style {
        Style::default()
            .fg(Color::Cyan)
            .add_modifier(Modifier::BOLD)
    }
    // <REMOVED UUID HERE> border :: auto-generated pointer for public function border
    pub fn border() -> Style {
        Style::default().fg(Color::DarkGray)
    }
    // <REMOVED UUID HERE> key_hint :: auto-generated pointer for public function key_hint
    pub fn key_hint() -> Style {
        Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
    }
    // <REMOVED UUID HERE> key_desc :: auto-generated pointer for public function key_desc
    pub fn key_desc() -> Style {
        Style::default().fg(Color::DarkGray)
    }
}

/// Map VerifyStatus to a colored symbol + style
// <REMOVED UUID HERE> status_display :: Map VerifyStatus to a colored symbol + style
pub fn status_display(status: &crate::engine::VerifyStatus) -> (&'static str, Style) {
    use crate::engine::VerifyStatus::*;
    match status {
        Ok => ("✓", Theme::ok()),
        Mismatch => ("≠", Theme::error()),
        MissingYaml => ("?", Theme::warn()),
        MissingDc => ("dc?", Theme::warn()),
        MissingInfisical => ("inf?", Theme::warn()),
        MissingAll => ("✗", Theme::error()),
    }
}
