use ratatui::style::{Color, Modifier, Style};

pub struct Theme;

impl Theme {
    // ⟦𓊑𓐪𓆰𓐗⟧ ok :: auto-generated pointer for public function ok
    pub fn ok() -> Style {
        Style::default().fg(Color::Green)
    }
    // ⟦𓍞𓁙𓋵𓋻⟧ error :: auto-generated pointer for public function error
    pub fn error() -> Style {
        Style::default().fg(Color::Red)
    }
    // ⟦𓃡𓇴𓆖𓏇⟧ warn :: auto-generated pointer for public function warn
    pub fn warn() -> Style {
        Style::default().fg(Color::Yellow)
    }
    // ⟦𓊑𓅒𓆇𓆳⟧ info :: auto-generated pointer for public function info
    pub fn info() -> Style {
        Style::default().fg(Color::Cyan)
    }
    // ⟦𓀝𓎕𓎰𓎟⟧ muted :: auto-generated pointer for public function muted
    pub fn muted() -> Style {
        Style::default().fg(Color::DarkGray)
    }
    // ⟦𓈲𓄿𓈡𓂝⟧ header :: auto-generated pointer for public function header
    pub fn header() -> Style {
        Style::default()
            .fg(Color::White)
            .add_modifier(Modifier::BOLD)
    }
    // ⟦𓐦𓅿𓋚𓅅⟧ selected :: auto-generated pointer for public function selected
    pub fn selected() -> Style {
        Style::default()
            .fg(Color::Black)
            .bg(Color::Cyan)
            .add_modifier(Modifier::BOLD)
    }
    // ⟦𓇬𓂄𓁳𓂢⟧ title :: auto-generated pointer for public function title
    pub fn title() -> Style {
        Style::default()
            .fg(Color::Cyan)
            .add_modifier(Modifier::BOLD)
    }
    // ⟦𓈯𓂅𓆧𓃸⟧ border :: auto-generated pointer for public function border
    pub fn border() -> Style {
        Style::default().fg(Color::DarkGray)
    }
    // ⟦𓌩𓅕𓎓𓅏⟧ key_hint :: auto-generated pointer for public function key_hint
    pub fn key_hint() -> Style {
        Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
    }
    // ⟦𓇩𓇓𓎭𓏀⟧ key_desc :: auto-generated pointer for public function key_desc
    pub fn key_desc() -> Style {
        Style::default().fg(Color::DarkGray)
    }
}

/// Map VerifyStatus to a colored symbol + style
// ⟦𓊆𓊭𓊿𓋼⟧ status_display :: Map VerifyStatus to a colored symbol + style
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
