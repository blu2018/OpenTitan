// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
//
// tb__xbar_connect generated by `topgen.py` tool
<%
from collections import OrderedDict

top_hier = 'tb.dut.top_' + top["name"] + '.'
clk_hier = top_hier + top["clocks"]["hier_paths"]["top"]

clk_src = {}
for xbar in top["xbar"]:
  for clk, src in xbar["clock_srcs"].items():
    clk_src[clk] = src

clk_freq = {}
for clock in top["clocks"]["srcs"]:
  if clock["name"] in clk_src.values():
    clk_freq[clock["name"]] = clock["freq"]

hosts = {}
devices = {}
for xbar in top["xbar"]:
  for node in xbar["nodes"]:
    if node["type"] == "host" and not node["xbar"]:
      hosts[node["name"]] = "clk_" + clk_src[node["clock"]]
    elif node["type"] == "device" and not node["xbar"]:
      devices[node["name"]] = "clk_" + clk_src[node["clock"]]
%>\
% for c in clk_freq.keys():
wire clk_${c};
clk_rst_if clk_rst_if_${c}(.clk(clk_${c}), .rst_n(rst_n));
% endfor

% for i, clk in hosts.items():
tl_if ${i}_tl_if(${clk}, rst_n);
% endfor

% for i, clk in devices.items():
tl_if ${i}_tl_if(${clk}, rst_n);
% endfor

initial begin
  bit xbar_mode;
  void'($value$plusargs("xbar_mode=%0b", xbar_mode));
  if (xbar_mode) begin
    // only enable assertions in xbar as many pins are unconnected
    $assertoff(0, tb);
% for xbar in top["xbar"]:
    $asserton(0, tb.dut.top_${top["name"]}.u_xbar_${xbar["name"]});
% endfor

% for c in clk_freq.keys():
    clk_rst_if_${c}.set_active(.drive_rst_n_val(0));
    clk_rst_if_${c}.set_freq_khz(${clk_freq[c]} / 1000);
% endfor

    // bypass clkmgr, force clocks directly
% for xbar in top["xbar"]:
  % for clk, src in xbar["clock_srcs"].items():
    force ${top_hier}u_xbar_${xbar["name"]}.${clk} = clk_${src};
  % endfor
% endfor

    // bypass rstmgr, force resets directly
% for xbar in top["xbar"]:
  % for rst in xbar["reset_connections"]:
    force ${top_hier}u_xbar_${xbar["name"]}.${rst} = rst_n;
  % endfor
% endfor

% for name, clk in hosts.items():
    `DRIVE_TL_HOST_IF(${name}, dut.top_${top["name"]}, ${clk}, rst_n, h_h2d, h_d2h)
% endfor

% for name, clk in devices.items():
    `DRIVE_TL_DEVICE_IF(${name}, dut.top_${top["name"]}, ${clk}, rst_n, d_d2h, d_h2d)
% endfor
  end
end
