// ============================================================================
// MODULE: tree_memory
// DESCRIPTION:
//   - Mô-đun lưu trữ và đọc thông tin các node của cây quyết định (Decision Tree)
//   - Dữ liệu cây được nạp từ file nhị phân (.mem) thông qua $readmemb()
//   - Khi tín hiệu `read_enable` được kích hoạt, module sẽ đọc node tương ứng
//     tại địa chỉ `node_addr` và tách các trường thông tin node ra thành tín hiệu riêng.
//
// TÍNH NĂNG CHÍNH:
//   ✅ Đọc dữ liệu node từ bộ nhớ cây
//   ✅ Tách thành các trường: node_id, feature_idx, threshold, left/right child, prediction
//   ✅ Xác định node lá (leaf)
//   ✅ Cờ data_valid báo dữ liệu hợp lệ
//   ✅ Giảm spam log bằng cách chỉ in thông tin khi địa chỉ thay đổi
//
// THÔNG SỐ CẤU HÌNH (PARAMETERS):
//   TREE_DEPTH     : Số lượng node trong cây (mặc định = 512)
//   NODE_WIDTH     : Số bit của mỗi node (mặc định = 95)
//   MEM_INIT_FILE  : Tên file chứa dữ liệu khởi tạo bộ nhớ cây
// ============================================================================

module tree_memory #(
    parameter TREE_DEPTH = 512,             // Số lượng node trong cây
    parameter NODE_WIDTH = 95,              // Độ rộng dữ liệu mỗi node (tổng số bit)
    parameter MEM_INIT_FILE = "tree.mem"    // File chứa dữ liệu cây (.mem)
)(
    // ======= INPUTS =======
    input               clk,                // Clock chính của hệ thống
    input               rst_n,              // Tín hiệu reset chủ động mức thấp
    input               read_enable,        // Cho phép đọc node từ bộ nhớ
    input   [8:0]       node_addr,          // Địa chỉ node cần đọc (0 → TREE_DEPTH-1)

    // ======= OUTPUTS =======
    output  reg [8:0]   node_id,            // Mã định danh (ID) của node hiện tại
    output  reg [1:0]   feature_idx,        // Chỉ số feature dùng để so sánh
    output  reg [63:0]  threshold,          // Ngưỡng so sánh (64-bit, fixed-point/float)
    output  reg [8:0]   left_child,         // Địa chỉ node con trái
    output  reg [8:0]   right_child,        // Địa chỉ node con phải
    output  reg [1:0]   prediction,         // Kết quả dự đoán (nếu node là lá)
    output  reg         is_leaf,            // Cờ báo node hiện tại là node lá
    output  reg         data_valid          // Cờ báo dữ liệu đầu ra hợp lệ
);

    // =========================================================================
    // BỘ NHỚ CHÍNH (Lưu toàn bộ dữ liệu cây)
    // -------------------------------------------------------------------------
    //   - Mỗi phần tử tương ứng với một node
    //   - Mỗi node được mã hóa trong 95 bit như sau:
    //
    //     | Bit Range | Field Name  | Mô tả                  |
    //     |------------|-------------|------------------------|
    //     | [94:86]    | node_id     | ID của node            |
    //     | [85:84]    | feature_idx | Chỉ số feature         |
    //     | [83:20]    | threshold   | Ngưỡng so sánh (64-bit)|
    //     | [19:11]    | left_child  | Địa chỉ con trái       |
    //     | [10:2]     | right_child | Địa chỉ con phải       |
    //     | [1:0]      | prediction  | Kết quả dự đoán        |
    // =========================================================================
    reg [NODE_WIDTH-1:0] tree_mem [0:TREE_DEPTH-1];

    reg [NODE_WIDTH-1:0] node_data;     // Dữ liệu node đang đọc
    reg [8:0] prev_addr;                // Lưu địa chỉ node trước đó để giảm spam log


    // =========================================================================
    // KHỞI TẠO BỘ NHỚ CÂY
    // -------------------------------------------------------------------------
    //   - Nếu có file MEM_INIT_FILE: nạp dữ liệu từ file .mem
    //   - Nếu không có: khởi tạo toàn bộ bộ nhớ = 0
    // =========================================================================
    integer i;
    initial begin
        if (MEM_INIT_FILE != "") begin
            $readmemb(MEM_INIT_FILE, tree_mem);
            $display("[TREE_MEM] Initialized from %s", MEM_INIT_FILE);
        end else begin
            for (i = 0; i < TREE_DEPTH; i = i + 1)
                tree_mem[i] = {NODE_WIDTH{1'b0}};
            $display("[TREE_MEM] Initialized with zeros");
        end
    end


    // =========================================================================
    // LUỒNG XỬ LÝ CHÍNH
    // -------------------------------------------------------------------------
    //   - Đọc node từ bộ nhớ khi `read_enable = 1`
    //   - Giải mã các trường dữ liệu node
    //   - Xác định node lá
    //   - Xuất tín hiệu ra ngoài
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset toàn bộ tín hiệu về 0
            node_data   <= {NODE_WIDTH{1'b0}};
            node_id     <= 9'b0;
            feature_idx <= 2'b0;
            threshold   <= 64'b0;
            left_child  <= 9'b0;
            right_child <= 9'b0;
            prediction  <= 2'b0;
            is_leaf     <= 1'b0;
            data_valid  <= 1'b0;
            prev_addr   <= 9'b0;

        end else begin
            if (read_enable) begin
                // Đọc dữ liệu node từ bộ nhớ
                node_data   <= tree_mem[node_addr];

                // Giải mã các trường dữ liệu node
                node_id     <= tree_mem[node_addr][94:86];
                feature_idx <= tree_mem[node_addr][85:84];
                threshold   <= tree_mem[node_addr][83:20];
                left_child  <= tree_mem[node_addr][19:11];
                right_child <= tree_mem[node_addr][10:2];
                prediction  <= tree_mem[node_addr][1:0];

                // Xác định node hiện tại là node lá nếu không có con trái & phải
                // is_leaf <= (tree_mem[node_addr][19:11] == 9'b0) &&
                //            (tree_mem[node_addr][10:2] == 9'b0);
                is_leaf <= tree_mem[node_addr][85] & tree_mem[node_addr][84]; // feature_idx == 3 (11)
                

                // Báo hiệu dữ liệu đầu ra hợp lệ
                data_valid <= 1'b1;

                // Ghi log khi đọc node mới (tránh spam)
                if (node_addr != prev_addr) begin
                    $display("[TREE_MEM] Read node %0d: Feature[%b] Threshold=%h Left=%0d Right=%0d Leaf=%b Pred=%b",
                             tree_mem[node_addr][94:86],
                             tree_mem[node_addr][85:84],
                             tree_mem[node_addr][83:20],
                             tree_mem[node_addr][19:11],
                             tree_mem[node_addr][10:2],
                             (tree_mem[node_addr][19:11] == 9'b0) && (tree_mem[node_addr][10:2] == 9'b0),
                             tree_mem[node_addr][1:0]);
                    prev_addr <= node_addr;
                end

            end else begin
                // Khi không đọc → ngắt cờ data_valid
                data_valid <= 1'b0;
            end
        end
    end

endmodule