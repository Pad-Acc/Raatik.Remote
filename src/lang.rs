use hbb_common::regex::Regex;
use std::ops::Deref;

mod en;
mod fa;

pub const LANGS: &[(&str, &str)] = &[("en", "English"), ("fa", "فارسی")];

pub(crate) fn cjk_ui_unavailable() -> bool {
    cfg!(all(
        target_os = "linux",
        target_arch = "aarch64",
        feature = "flutter"
    ))
}

pub(crate) fn is_cjk_lang(lang_or_locale: &str) -> bool {
    let lang = lang_or_locale
        .split(|c| c == '-' || c == '_')
        .next()
        .unwrap_or_default()
        .to_lowercase();
    matches!(lang.as_str(), "zh" | "ja" | "ko")
}

fn resolve_lang(saved_lang: &str, _locale: &str, cjk_fallback: bool) -> String {
    // RAATIK: default to Farsi when no language preference has been saved,
    // instead of following the host OS/browser locale (`_locale`). A saved
    // preference (e.g. the user explicitly picking "en" via the language
    // selector) always takes priority and is handled above/below unchanged,
    // so switching back to English continues to work.
    let mut lang = saved_lang.to_lowercase();
    if cjk_fallback && is_cjk_lang(&lang) {
        return "en".to_owned();
    }
    if lang.is_empty() {
        lang = "fa".to_owned();
    }
    if cjk_fallback && is_cjk_lang(&lang) {
        "en".to_owned()
    } else {
        lang
    }
}

#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub fn translate(name: String) -> String {
    let locale = sys_locale::get_locale().unwrap_or_default();
    translate_locale(name, &locale)
}

pub fn translate_locale(name: String, locale: &str) -> String {
    let lang = resolve_lang(
        &hbb_common::config::LocalConfig::get_option("lang"),
        locale,
        cjk_ui_unavailable(),
    );
    let m = match lang.as_str() {
        "fa" => fa::T.deref(),
        _ => en::T.deref(),
    };
    let (name, placeholder_value) = extract_placeholder(&name);
    let replace = |s: &&str| {
        let mut s = s.to_string();
        if let Some(value) = placeholder_value.as_ref() {
            s = s.replace("{}", &value);
        }
        if !crate::is_rustdesk() {
            if s.contains("RustDesk") {
                let app_name = crate::get_app_name();
                if !app_name.contains("RustDesk") {
                    s = s.replace("RustDesk", &app_name);
                } else {
                    // https://github.com/rustdesk/rustdesk-server-pro/issues/845
                    // If app_name contains "RustDesk" (e.g., "RustDesk-Admin"), we need to avoid
                    // replacing "RustDesk" within the already-substituted app_name, which would
                    // cause duplication like "RustDesk-Admin" -> "RustDesk-Admin-Admin".
                    //
                    // app_name only contains alphanumeric and hyphen.
                    const PLACEHOLDER: &str = "#A-P-P-N-A-M-E#";
                    if !s.contains(PLACEHOLDER) {
                        s = s.replace(&app_name, PLACEHOLDER);
                        s = s.replace("RustDesk", &app_name);
                        s = s.replace(PLACEHOLDER, &app_name);
                    } else {
                        // It's very unlikely to reach here.
                        // Skip replacement to avoid incorrect result.
                    }
                }
            }
        }
        s
    };
    if let Some(v) = m.get(&name as &str) {
        if !v.is_empty() {
            return replace(v);
        }
    }
    if lang != "en" {
        if let Some(v) = en::T.get(&name as &str) {
            if !v.is_empty() {
                return replace(v);
            }
        }
    }
    replace(&name.as_str())
}

// Matching pattern is {}
// Write {value} in the UI and {} in the translation file
//
// Example:
// Write in the UI: translate("There are {24} hours in a day")
// Write in the translation file: ("There are {} hours in a day", "{} hours make up a day")
fn extract_placeholder(input: &str) -> (String, Option<String>) {
    if let Ok(re) = Regex::new(r#"\{(.*?)\}"#) {
        if let Some(captures) = re.captures(input) {
            if let Some(inner_match) = captures.get(1) {
                let name = re.replace(input, "{}").to_string();
                let value = inner_match.as_str().to_string();
                return (name, Some(value));
            }
        }
    }
    (input.to_string(), None)
}

mod test {
    #[test]
    fn test_extract_placeholders() {
        use super::extract_placeholder as f;

        assert_eq!(f(""), ("".to_string(), None));
        assert_eq!(
            f("{3} sessions"),
            ("{} sessions".to_string(), Some("3".to_string()))
        );
        assert_eq!(f(" } { "), (" } { ".to_string(), None));
        // Allow empty value
        assert_eq!(
            f("{} sessions"),
            ("{} sessions".to_string(), Some("".to_string()))
        );
        // Match only the first one
        assert_eq!(
            f("{2} times {4} makes {8}"),
            ("{} times {4} makes {8}".to_string(), Some("2".to_string()))
        );
    }

    #[test]
    fn test_resolve_lang_forces_english_for_saved_cjk_when_target_disables_cjk() {
        use super::resolve_lang as f;

        assert_eq!(f("zh-cn", "en-US", true), "en");
        assert_eq!(f("zh-tw", "en-US", true), "en");
        assert_eq!(f("ja", "en-US", true), "en");
        assert_eq!(f("ko", "en-US", true), "en");
    }

    #[test]
    fn test_resolve_lang_defaults_to_farsi_regardless_of_host_locale() {
        // RAATIK: this fork ships only English and Farsi, and the app must
        // default to Farsi rather than sniffing the host OS/browser locale.
        // The `locale` argument (formerly used to detect e.g. zh/ja/ko) is
        // now ignored entirely when no preference has been saved.
        use super::resolve_lang as f;

        assert_eq!(f("", "zh_CN", true), "fa");
        assert_eq!(f("", "ja-JP", true), "fa");
        assert_eq!(f("", "ko_KR", true), "fa");
        assert_eq!(f("", "zh_TW", false), "fa");
        assert_eq!(f("", "en-US", false), "fa");
        assert_eq!(f("", "", false), "fa");
    }

    #[test]
    fn test_resolve_lang_preserves_saved_choice() {
        // A saved preference always wins over the Farsi default, so users
        // can still switch to (and stay on) English via the language
        // selector.
        use super::resolve_lang as f;

        assert_eq!(f("zh-cn", "en-US", false), "zh-cn");
        assert_eq!(f("en", "fa-IR", false), "en");
        assert_eq!(f("fa", "en-US", false), "fa");
    }

    #[test]
    fn test_only_english_and_farsi() {
        assert_eq!(super::LANGS.len(), 2);
        assert_eq!(super::LANGS[0].0, "en");
        assert_eq!(super::LANGS[1].0, "fa");
    }

    #[test]
    fn test_brand_substituted() {
        // "Show RustDesk" is not overridden in en.rs (key == English text)
        // and fa.rs keeps the "RustDesk" brand token untranslated per
        // AGENTS.md, so this assertion holds regardless of which of the two
        // shipped languages the default resolves to.
        let s = super::translate_locale("Show RustDesk".to_owned(), "en");
        assert!(s.contains(&crate::get_app_name()), "not substituted: {s}");
        assert!(!s.contains("RustDesk"), "brand leaked: {s}");
    }

    #[test]
    fn test_farsi_has_no_empty_values() {
        for (k, v) in super::fa::T.iter() {
            assert!(!v.is_empty(), "untranslated Farsi key: {k}");
        }
    }

    #[test]
    fn test_deleted_lang_code_does_not_panic() {
        // "de" was one of the 48 non-en/fa language files removed in this
        // fork. Even if a legacy config still has "de" saved as a
        // preference, `resolve_lang` must pass it through unchanged (it no
        // longer maps to a `mod`/match arm), and `translate_locale` must
        // fall back to English rather than panicking on the lookup.
        assert_eq!(super::resolve_lang("de", "en-US", false), "de");

        let s = super::translate_locale("Settings".to_owned(), "de");
        assert!(!s.is_empty());
    }

    #[test]
    fn test_no_brand_leak_in_translated_output() {
        // fa.rs carries the full key set (template.rs is a reference file
        // only and is not a compiled module), so iterating its keys covers
        // every translatable string in the app. This used to fail for
        // "powered_by_me" and "upgrade_rustdesk_server_pro_to_{}_tip",
        // which were exempted from the "RustDesk" -> app-name substitution
        // above; now that both raw values are branded directly (see en.rs
        // / fa.rs), the exemption is gone and no value should ever surface
        // the literal "RustDesk" in translated output.
        let prev = hbb_common::config::LocalConfig::get_option("lang");
        for (k, _) in super::fa::T.iter() {
            for locale in ["en", "fa"] {
                hbb_common::config::LocalConfig::set_option("lang".to_owned(), locale.to_owned());
                let out = super::translate_locale(k.to_string(), locale);
                assert!(
                    !out.contains("RustDesk"),
                    "brand leaked for key {k} in {locale}: {out}"
                );
            }
        }
        hbb_common::config::LocalConfig::set_option("lang".to_owned(), prev);
    }

    #[test]
    fn test_powered_by_is_branded() {
        let prev = hbb_common::config::LocalConfig::get_option("lang");
        hbb_common::config::LocalConfig::set_option("lang".to_owned(), "en".to_owned());
        let s = super::translate_locale("powered_by_me".to_owned(), "en");
        assert_eq!(s, "Powered by RaatikDesk");
        hbb_common::config::LocalConfig::set_option("lang".to_owned(), prev);
    }
}
