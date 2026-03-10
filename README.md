# Mac Clean CLI

Công cụ dọn dẹp Mac dạng command line với giao diện TUI (menu điều hướng bằng phím mũi tên).

## Tính năng

- **Scan Large Files**: Quét file có dung lượng lớn (mặc định từ 100MB), chọn từng file để xóa.
- **Scan Large Dirs**: Quét thư mục chiếm nhiều dung lượng, chọn thư mục để xóa.
- **Clean Common Caches**: Xóa cache phổ biến (User Caches, Logs, Xcode, npm/yarn/pip, Homebrew, Gradle/Maven, Trash) — chọn từng mục hoặc "Clean ALL".
- **Quick Clean All**: Xóa nhanh User Caches, Logs, npm/yarn/pip, Homebrew cache, Trash (một lần xác nhận).
- **View Last Report**: Xem log các thao tác xóa gần nhất (~/.mac_clean.log).
- **Settings**: Đổi thư mục quét và ngưỡng dung lượng tối thiểu (min file size).

## Yêu cầu

- macOS
- Bash (có sẵn)
- Các lệnh chuẩn: `find`, `du`, `stat`, `sort`, `tput`

## Cài đặt

```bash
cd /path/to/mac_clean
chmod +x mac_clean.sh
./mac_clean.sh
```

Chạy từ bất kỳ đâu (thêm vào PATH):

```bash
sudo ln -sf "$(pwd)/mac_clean.sh" /usr/local/bin/macclean
macclean
```

## Sử dụng

1. Chạy `./mac_clean.sh` (hoặc `macclean` nếu đã link).
2. Dùng **phím mũi tên lên/xuống** để di chuyển trong menu.
3. **Enter** để chọn mục.
4. **q** để thoát menu hoặc quay lại.
5. Khi chọn xóa file/thư mục/cache, chương trình sẽ hỏi xác nhận trước khi xóa.

## Cấu trúc thư mục

```
mac_clean/
├── mac_clean.sh    # Điểm vào, menu chính
├── lib/
│   ├── ui.sh       # Menu TUI, màu, progress bar, confirm
│   ├── utils.sh    # format_bytes, safe_delete, log
│   ├── scanner.sh  # Quét file/thư mục lớn
│   └── cleaner.sh  # Danh sách cache và xóa
└── README.md
```

## Log

Các thao tác xóa được ghi vào `~/.mac_clean.log` (thời gian, hành động, đường dẫn, kết quả).

## Lưu ý

- Chỉ xóa khi bạn đã chọn và xác nhận; nên kiểm tra kỹ đường dẫn trước khi xóa.
- Xóa Xcode DerivedData / CoreSimulator có thể khiến build lại lâu hoặc cần tải lại simulator.
- "Quick Clean All" không bao gồm Xcode/Docker/Gradle/Maven; dùng "Clean Common Caches" để chọn từng mục.

