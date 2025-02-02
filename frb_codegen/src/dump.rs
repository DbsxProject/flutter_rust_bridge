#![cfg(feature = "serde")]

use std::collections::HashMap;

use crate::{config::Dump, Opts};
use enum_iterator::all;

pub fn dump_multi(configs: &[Opts], dump: Vec<Dump>) -> anyhow::Result<()> {
    let dump = if dump.is_empty() {
        all().collect()
    } else {
        dump
    };
    let data = configs
        .iter()
        .map(|config| {
            let mut data = HashMap::new();
            for request in &dump {
                match request {
                    Dump::Config => data.insert("config", serde_yaml::to_value(config)?),
                    Dump::Ir => data.insert("ir", config.get_ir_file().map(serde_yaml::to_value)??),
                };
            }
            Ok(data)
        })
        .collect::<anyhow::Result<Vec<_>>>()?;
    let data = serde_yaml::to_string(&data)?;
    println!("{data}");
    Ok(())
}
