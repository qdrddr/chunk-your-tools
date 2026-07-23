//! Catalog I/O and `CatalogBuilder` opaque handle FFI exports.

use crate::catalog_builder::CatalogBuilder;
use crate::catalog_io::{load_catalog_index_from_dir, write_catalog_index_resolved};
use crate::ffi::error::{
    CHUNK_YOUR_TOOLS_ERR_INVALID_HANDLE, CHUNK_YOUR_TOOLS_ERR_IO, CHUNK_YOUR_TOOLS_ERR_NULL_PTR,
    clear_error, set_error,
};
use crate::ffi::json_util::{
    c_str_to_str, catalog_index_from_json, parse_json_cstr, run_ffi, write_json_out,
};
use serde_json::json;
use std::os::raw::{c_char, c_int};
use std::path::PathBuf;

/// Opaque catalog builder handle.
pub struct ChunkYourToolsCatalogBuilder {
    pub(crate) inner: CatalogBuilder,
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn chunk_your_tools_catalog_builder_new(
    memory_only: c_int,
    output_dir: *const c_char,
    out: *mut *mut ChunkYourToolsCatalogBuilder,
) -> c_int {
    run_ffi(|| {
        if out.is_null() {
            set_error("null pointer: out");
            return Err(CHUNK_YOUR_TOOLS_ERR_NULL_PTR);
        }
        let dir = if output_dir.is_null() {
            None
        } else {
            Some(PathBuf::from(unsafe {
                c_str_to_str(output_dir, "output_dir")?
            }))
        };
        let memory = if memory_only < 0 {
            None
        } else {
            Some(memory_only != 0)
        };
        unsafe {
            *out = Box::into_raw(Box::new(ChunkYourToolsCatalogBuilder {
                inner: CatalogBuilder::new_with_options(memory, dir),
            }));
        }
        clear_error();
        Ok(())
    })
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn chunk_your_tools_catalog_builder_free(
    builder: *mut ChunkYourToolsCatalogBuilder,
) {
    if !builder.is_null() {
        let _ = Box::from_raw(builder);
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn chunk_your_tools_catalog_builder_add_tool(
    builder: *mut ChunkYourToolsCatalogBuilder,
    entry_json: *const c_char,
) -> c_int {
    run_ffi(|| {
        if builder.is_null() {
            set_error("null pointer: builder");
            return Err(CHUNK_YOUR_TOOLS_ERR_INVALID_HANDLE);
        }
        let entry = unsafe { parse_json_cstr(entry_json, "entry_json")? };
        unsafe { (*builder).inner.add_tool(entry) };
        clear_error();
        Ok(())
    })
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn chunk_your_tools_catalog_builder_get_tool_info(
    builder: *const ChunkYourToolsCatalogBuilder,
    server_name: *const c_char,
    tool_name: *const c_char,
    out: *mut *mut c_char,
) -> c_int {
    run_ffi(|| {
        if builder.is_null() {
            set_error("null pointer: builder");
            return Err(CHUNK_YOUR_TOOLS_ERR_INVALID_HANDLE);
        }
        if out.is_null() {
            set_error("null pointer: out");
            return Err(CHUNK_YOUR_TOOLS_ERR_NULL_PTR);
        }
        let server = unsafe { c_str_to_str(server_name, "server_name")? };
        let tool = unsafe { c_str_to_str(tool_name, "tool_name")? };
        if let Some(v) = unsafe { (*builder).inner.get_tool_info(server, tool) } {
            unsafe { write_json_out(v, out)? };
        } else {
            unsafe { *out = std::ptr::null_mut() };
            clear_error();
        }
        Ok(())
    })
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn chunk_your_tools_catalog_builder_build_index(
    builder: *mut ChunkYourToolsCatalogBuilder,
    out: *mut *mut c_char,
) -> c_int {
    run_ffi(|| {
        if builder.is_null() {
            set_error("null pointer: builder");
            return Err(CHUNK_YOUR_TOOLS_ERR_INVALID_HANDLE);
        }
        if out.is_null() {
            set_error("null pointer: out");
            return Err(CHUNK_YOUR_TOOLS_ERR_NULL_PTR);
        }
        let index = unsafe { (*builder).inner.build_index() };
        unsafe {
            write_json_out(&json!({ "tools": index.tools, "files": index.files }), out)?;
        }
        Ok(())
    })
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn chunk_your_tools_catalog_builder_write_catalog(
    builder: *mut ChunkYourToolsCatalogBuilder,
    out: *mut *mut c_char,
) -> c_int {
    run_ffi(|| {
        if builder.is_null() {
            set_error("null pointer: builder");
            return Err(CHUNK_YOUR_TOOLS_ERR_INVALID_HANDLE);
        }
        if out.is_null() {
            set_error("null pointer: out");
            return Err(CHUNK_YOUR_TOOLS_ERR_NULL_PTR);
        }
        let index = unsafe { (*builder).inner.write_catalog() }.map_err(|e| {
            set_error(&e);
            CHUNK_YOUR_TOOLS_ERR_IO
        })?;
        unsafe {
            write_json_out(&json!({ "tools": index.tools, "files": index.files }), out)?;
        }
        Ok(())
    })
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn chunk_your_tools_catalog_builder_to_catalog_dict(
    builder: *mut ChunkYourToolsCatalogBuilder,
    catalog_prefix: *const c_char,
    out: *mut *mut c_char,
) -> c_int {
    run_ffi(|| {
        if builder.is_null() {
            set_error("null pointer: builder");
            return Err(CHUNK_YOUR_TOOLS_ERR_INVALID_HANDLE);
        }
        if out.is_null() {
            set_error("null pointer: out");
            return Err(CHUNK_YOUR_TOOLS_ERR_NULL_PTR);
        }
        let val = if catalog_prefix.is_null() {
            unsafe { (*builder).inner.to_catalog_dict() }
        } else {
            let prefix = unsafe { c_str_to_str(catalog_prefix, "catalog_prefix")? };
            unsafe { (*builder).inner.to_catalog_dict_with_prefix(prefix) }
        };
        unsafe { write_json_out(&val, out)? };
        Ok(())
    })
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn chunk_your_tools_load_catalog_index_from_dir(
    dir_path: *const c_char,
    out: *mut *mut c_char,
) -> c_int {
    run_ffi(|| {
        if out.is_null() {
            set_error("null pointer: out");
            return Err(CHUNK_YOUR_TOOLS_ERR_NULL_PTR);
        }
        let dir = unsafe { c_str_to_str(dir_path, "dir_path")? };
        let index = load_catalog_index_from_dir(std::path::Path::new(dir)).map_err(|e| {
            set_error(&e);
            CHUNK_YOUR_TOOLS_ERR_IO
        })?;
        unsafe {
            write_json_out(&json!({ "tools": index.tools, "files": index.files }), out)?;
        }
        Ok(())
    })
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn chunk_your_tools_write_catalog_index(
    index_json: *const c_char,
    output_dir: *const c_char,
    prune: c_int,
) -> c_int {
    run_ffi(|| {
        let val = unsafe { parse_json_cstr(index_json, "index_json")? };
        let catalog = catalog_index_from_json(&val);
        let dir = if output_dir.is_null() {
            None
        } else {
            Some(std::path::Path::new(unsafe {
                c_str_to_str(output_dir, "output_dir")?
            }))
        };
        let prune_opt = if prune < 0 { None } else { Some(prune != 0) };
        write_catalog_index_resolved(&catalog, dir, prune_opt).map_err(|e| {
            set_error(&e);
            CHUNK_YOUR_TOOLS_ERR_IO
        })?;
        clear_error();
        Ok(())
    })
}
