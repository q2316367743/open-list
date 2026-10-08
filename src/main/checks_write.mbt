///|
/// 写入自测：只在 `<测试目录>/open-list-self-test` 里创建、改名和删除文件。

///|
/// 顺序跑一遍写接口，每步失败只记录并继续。只有只读端点会额外打原始数据，
/// 写端点只调一次类型化方法，避免重复产生副作用。
pub async fn check_write(
  client : @lib.OpenListClient,
  test_dir : String,
  is_admin : Bool,
) -> Unit {
  section("写入自测（只动 open-list-self-test 子目录）")
  let work = "\{test_dir}/open-list-self-test"
  say("工作目录：\{work}")
  let _ = check(
    "POST /api/fs/mkdir",
    "fs().mkdir(work)",
    Ok(client.fs().mkdir(work)) catch {
      error => Err(error)
    },
    fn(_) { "已创建目录" },
  )
  let text = "hello from open-list MoonBit client\n中文也要能传\n"
  let _ = check(
    "PUT /api/fs/put",
    "fs().put_bytes(work + \"/hello.txt\")",
    Ok(
      client
      .fs()
      .put_bytes(
        "\{work}/hello.txt",
        @utf8.encode(text),
        content_type="text/plain",
      ),
    ) catch {
      error => Err(error)
    },
    task_result,
  )
  let _ = check(
    "PUT /api/fs/put (As-Task)",
    "fs().put_bytes(work + \"/task.txt\", as_task=true)",
    Ok(
      client
      .fs()
      .put_bytes(
        "\{work}/task.txt",
        @utf8.encode(text),
        as_task=true,
        content_type="text/plain",
      ),
    ) catch {
      error => Err(error)
    },
    task_result,
  )
  let _ = check(
    "PUT /api/fs/form",
    "fs().put_form(work + \"/form.txt\", \"form.txt\")",
    Ok(
      client
      .fs()
      .put_form(
        "\{work}/form.txt",
        "form.txt",
        @utf8.encode(text),
        content_type="text/plain",
      ),
    ) catch {
      error => Err(error)
    },
    task_result,
  )
  let _ = check(
    "POST /api/fs/multipart/init → chunk → complete",
    "fs().multipart_upload(work + \"/big.bin\", 3MB)",
    Ok(
      client
      .fs()
      .multipart_upload(
        "\{work}/big.bin",
        @utf8.encode("0123456789".repeat(300_000)),
        chunk_size=1_048_576,
      ),
    ) catch {
      error => Err(error)
    },
    fn(snapshot) {
      "state=\{snapshot.state}，已收 \{snapshot.received_bytes}/\{snapshot.size} 字节，分片 \{snapshot.received.length()}/\{snapshot.total_chunks}"
    },
  )
  let listing = check(
    "POST /api/fs/list",
    "fs().list(work, refresh=true)",
    Ok(client.fs().list(work, refresh=true, page=1, per_page=50)) catch {
      error => Err(error)
    },
    fn(page) {
      "total=\{page.total}，写入后 \{page.content.length()} 个文件"
    },
  )
  dump_raw(
    client,
    @lib.Method::Post,
    "/api/fs/list",
    body=Json::object({
      "path": Json::string(work),
      "page": Json::number(1),
      "per_page": Json::number(50),
      "refresh": Json::boolean(true),
    }),
  )
  match listing {
    Some(page) => {
      say("     写入后的条目：")
      say(entry_lines(page.content))
    }
    None => ()
  }
  let _ = check(
    "POST /api/fs/get",
    "fs().get(work + \"/hello.txt\")",
    Ok(client.fs().get("\{work}/hello.txt")) catch {
      error => Err(error)
    },
    fn(response) { obj_summary(response.obj) },
  )
  let _ = check(
    "POST /api/fs/rename",
    "fs().rename(hello.txt → renamed.txt)",
    Ok(client.fs().rename("\{work}/hello.txt", "renamed.txt")) catch {
      error => Err(error)
    },
    fn(_) { "已改名" },
  )
  if is_admin {
    let _ = check(
      "POST /api/fs/link",
      "fs().create_link(work + \"/task.txt\")",
      Ok(client.fs().create_link("\{work}/task.txt")) catch {
        error => Err(error)
      },
      fn(link) {
        "url=\{brief(link.url, 60)} 并发=\{link.concurrency} 分片大小=\{link.part_size}"
      },
    )
  } else {
    skip(
      "POST /api/fs/link", "fs().create_link(path)", "只有管理员能调用",
    )
  }
  check_share_write(client, work)
  let _ = check(
    "POST /api/fs/remove",
    "fs().remove(work, [...])",
    Ok(
      client
      .fs()
      .remove(work, ["renamed.txt", "task.txt", "form.txt", "big.bin"]),
    ) catch {
      error => Err(error)
    },
    fn(_) { "已删除 4 个文件" },
  )
  let _ = check(
    "POST /api/fs/remove_empty_directory",
    "fs().remove_empty_directory(work)",
    Ok(client.fs().remove_empty_directory(work)) catch {
      error => Err(error)
    },
    fn(_) { "已删除自测目录" },
  )
}

///|
/// 分享的写入自测：创建 → 查询 → 禁用 → 删除。
async fn check_share_write(client : @lib.OpenListClient, work : String) -> Unit {
  let request = @lib.SharingUpdateRequest::new(
    ["\{work}/task.txt"],
    pwd="1234",
    remark="open-list 联调自测",
  )
  let created = check(
    "POST /api/share/create",
    "share().create(files → task.txt)",
    Ok(client.share().create(request)) catch {
      error => Err(error)
    },
    sharing_summary,
  )
  match created {
    Some(sharing) => {
      let _ = check(
        "GET /api/share/get",
        "share().get(id)",
        Ok(client.share().get(sharing.id)) catch {
          error => Err(error)
        },
        sharing_summary,
      )
      dump_raw(
        client,
        @lib.Method::Get,
        "/api/share/get",
        query=Json::object({ "id": Json::string(sharing.id) }),
      )
      let _ = check(
        "POST /api/share/disable",
        "share().disable(id)",
        Ok(client.share().disable(sharing.id)) catch {
          error => Err(error)
        },
        fn(_) { "已禁用分享 \{sharing.id}" },
      )
      let _ = check(
        "POST /api/share/delete",
        "share().delete(id)",
        Ok(client.share().delete(sharing.id)) catch {
          error => Err(error)
        },
        fn(_) { "已删除分享 \{sharing.id}" },
      )
    }
    None => ()
  }
}
