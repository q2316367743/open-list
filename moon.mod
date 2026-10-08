// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "q2316367743/open-list"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/q2316367743/open-list"

license = "Apache-2.0"

keywords = [ "openlist", "http", "client", "api", "alist" ]

// 请求最终要靠 moonbitlang/async 的异步运行时发出，
// 该包官方偏好 native 后端（wasm 上的异步支持仍标注为实验性），
// 所以本模块也以 native 为默认构建目标。

preferred_target = "native"

// 业务代码全部放在 src/ 下：模块根包即 src/ 本身，
// 根目录只保留模块元数据与文档（见 AGENTS.md 的 RL-02）。

source = "src"

description = "OpenList API 的 MoonBit 客户端：认证、用户、管理、文件系统、公开接口与分享六个子模块"

// moonhttp 提供 HTTP 客户端；async 提供二进制上传要用的 Reader 抽象
// （moonhttp 的请求体只有字符串/JSON/表单/流四种形态，没有裸字节构造器）。

import {
  "moonbitlang/async@0.22.4",
  "q2316367743/moonhttp@0.5.0",
}
