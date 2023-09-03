// I hate writing haskell code, so I defer a lot of things to c++

#include <algorithm>
#include <array>
#include <cmath>
#include <filesystem>
#include <fmt/ranges.h>
#include <fstream>
#include <ifaddrs.h>
#include <iostream>
#include <netdb.h>
#include <optional>
#include <regex>
#include <sstream>
#include <string>
#include <string_view>
#include <sys/socket.h>
#include <sys/statvfs.h>
#include <unordered_map>
#include <vector>

// colorscheme colors
#define RED "#e74c4c"
#define ORANGE "#e59e67"
#define GREEN "#6bb05d"
#define INFO_ALT "#8dc776"

inline static constexpr auto NA = "<fc=" RED ">n/a</fc>";

#define _fc(color, block) "<fc=" color ">" block "</fc>"
#define fc(color, block) _fc(color, block)
#define red(block) fc(RED, block)
#define orange(block) fc(ORANGE, block)
#define green(block) fc(GREEN, block)
#define alt(block) fc(INFO_ALT, block)

namespace
{
    static void ltrim(std::string& s)
    {
        s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](unsigned char ch) { return !std::isspace(ch); }));
    }

    static void rtrim(std::string& s)
    {
        s.erase(std::find_if(s.rbegin(), s.rend(), [](unsigned char ch) { return !std::isspace(ch); }).base(), s.end());
    }

    static inline void trim(std::string& s)
    {
        ltrim(s);
        rtrim(s);
    }

    static inline auto trim(const std::string& s)
    {
        std::string tmp = s;
        trim(tmp);
        return tmp;
    }

    static std::optional<std::unordered_map<std::string, std::string>> regex_parse(const std::string& str, const std::string& pattern)
    {
        std::smatch match;
        if (!std::regex_match(str, match, std::regex(pattern)))
        {
            return std::nullopt;
        }

        std::unordered_map<std::string, std::string> captureGroups;
        for (size_t i = 0; i < match.size(); ++i)
        {
            const std::string& groupName = match.empty() ? std::to_string(i) : std::to_string(i);
            captureGroups[groupName] = match.str(i);
        }

        return captureGroups;
    }
} // namespace

// Util functions
namespace
{
    template <typename... Args>
    [[noreturn]] void err(const fmt::format_string<Args...>& str, Args&&... args)
    {
        std::cerr << fmt::format(str, std::forward<Args>(args)...);
        std::cerr << '\n';
        exit(-1);
    }

    template <typename T>
    T vread(const std::filesystem::path& path, char delim = ' ')
    {
        T tmp;
        std::ifstream fs(path);
        if (!fs)
            err("Failed to open file: {}", path.string());

        if constexpr (std::is_same_v<T, std::string>)
            std::getline(fs, tmp, delim);
        else
            fs >> tmp;
        return tmp;
    }

    template <typename T>
    T vread_n(const std::vector<std::string>& paths, char delim = ' ')
    {
        T tmp;

        for (const auto& i : paths)
        {
            std::ifstream fs(i);
            if (!fs)
                continue;

            if constexpr (std::is_same_v<T, std::string>)
                std::getline(fs, tmp, delim);
            else
                fs >> tmp;
            return tmp;
        }

        err("Failed to open file: {}", paths);
    }

    static std::string exec(const std::string_view& cmd)
    {
        std::array<char, 128> buffer;
        std::string result;
        std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.data(), "r"), pclose);
        if (!pipe)
        {
            throw std::runtime_error("popen() failed!");
        }
        while (fgets(buffer.data(), buffer.size(), pipe.get()) != nullptr)
        {
            result += buffer.data();
        }

        trim(result);
        return result;
    }

    template <typename T>
    static std::string color_for(T value, const std::vector<std::pair<T, std::string>>& V)
    {
        for (const auto& i : V)
            if (value > i.first)
                return i.second;
        return V.back().second;
    }

    static std::string color(const std::string_view& color, const std::string_view& str)
    {
        return fmt::format("<fc={}>{}</fc>", color, str);
    }
} // namespace

// display functions
namespace inet
{
    bool is_up(const std::string_view& interface)
    {
        return trim(vread<std::string>(fmt::format("/sys/class/net/{}/operstate", interface))) == "up";
    }

    std::optional<std::string> local_ip(const std::string_view& interface)
    {
        if(!is_up(interface))
            return std::nullopt;

        struct ifaddrs *ifaddr, *ifa;
        char host[NI_MAXHOST];

        if (getifaddrs(&ifaddr) < 0)
        {
            return NA;
        }

        for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next)
        {
            if (!ifa->ifa_addr)
                continue;

            int res = getnameinfo(ifa->ifa_addr, sizeof(struct sockaddr_in6), host, NI_MAXHOST, NULL, 0, NI_NUMERICHOST);
            if (ifa->ifa_name == interface.data() && (ifa->ifa_addr->sa_family == AF_INET))
            {
                freeifaddrs(ifaddr);
                if (res != 0)
                    return std::nullopt;

                return host;
            }
        }

        freeifaddrs(ifaddr);

        return std::nullopt;
    }

    std::optional<std::string> network_name(const std::string_view& interface) 
    {
        if(!is_up(interface))
            return std::nullopt;
        return regex_parse(exec("iwgetid"), "ESSID:\"(.+)\"").value()["1"];
    }

    // 0 = worse, 1 = best
    double network_strength(const std::string_view& interface)
    {
        if(!is_up(interface))
            return 0;
        
        std::ifstream ifs("/proc/net/wireless");

        ifs.ignore(10000, ifs.widen('\n'));
        ifs.ignore(10000, ifs.widen('\n'));

        std::string ignore;
        double value = 0;
        ifs >> ignore >> ignore >> value;
        return value / 70;
    }

    std::optional<std::string> network_string_bars(const std::string_view& interface, const std::string_view& chars)
    {
        return std::string(chars.data(), std::round(network_strength(interface) * chars.length()));
    }
}

namespace power 
{
    // 0 = empty, 100 = full
    int current_charge_percent()
    {
        return  vread<int>("/sys/class/power_supply/BAT1/capacity");
    }
}

    std::string battery()
    {
        using namespace std::string_view_literals;
        int value = vread<int>("/sys/class/power_supply/BAT1/capacity");
        std::string color = "";

        color = color_for(value, {{50, GREEN}, {20, ORANGE}, {0, RED}});

        std::string mode = vread<std::string>("/sys/class/power_supply/BAT1/status");
        trim(mode);
        constexpr static std::pair<const char*, const char*> SYM_MAP[] = {
            {"Charging", "<fc=#b185db>+</fc>"}, {"Discharging", "<fc=#e59e67>-</fc>"}, {"Full", "<fc=#8dc776>f</fc>"}, {"Not Charging", " "}};

        const char* mode_str = "?";
        for (const auto& i : SYM_MAP)
        {
            if (mode == i.first)
            {
                mode_str = i.second;
                break;
            }
        }

        std::string charge_str = "";
        if (mode == "Discharging"sv)
        {
            int charge_now = vread<int>("/sys/class/power_supply/BAT1/charge_now");
            int power_now = vread_n<int>({"/sys/class/power_supply/BAT1/power_now", "/sys/class/power_supply/BAT1/current_now"});

            auto timeleft = (double)charge_now / power_now;
            int h = timeleft;
            int m = (timeleft - (double)h) * 60;
            charge_str = fmt::format("{}h {}m", h, m);
        }

        std::string color_txt = std::to_string(value);
        std::size_t padding = 17 - (color_txt.size() + 6 + charge_str.size());

        return fmt::format(" <fc={}>{}</fc>% ({}) {}{:{}} ", color, color_txt, mode_str, charge_str, ' ', padding);
    }

    std::string audio()
    {
        std::string res = exec("awk -F\"[][]\" \'/Left:/ { print $2 }\' <(amixer sget Master)");
        std::string color = color_for(strtol(res.c_str(), nullptr, 10), {{{66, GREEN}, {33, ORANGE}, {0, RED}}});
        return fmt::format(" <fc={}>{}</fc>", color, res);
    }

    std::string hostname()
    {
        return fmt::format("<fc=#51a39f>{}</fc>@<fc=#b185db>{}</fc>", exec("whoami"), trim(vread<std::string>("/etc/hostname")));
    }
    auto ram_info()
    {
        intmax_t total, free, avail, buffers, cached;
        std::string val;
        std::ifstream ifs("/proc/meminfo");
        ifs >> val >> total >> val >> val >> free >> val >> val >> avail >> val >> val >> buffers >> val >> val >> cached >> val;
        return std::tuple(total, free, avail, buffers, cached);
    }

    auto swp_info()
    {
        std::istringstream is(exec("cat /proc/meminfo | grep Swap"));
        intmax_t total, free, cached;
        std::string val;
        is >> val >> cached >> val >> val >> total >> val >> val >> free >> val;

        return std::tuple(total, free, cached);
    }

    std::string ram_perc()
    {
        auto [total, free, avail, buffers, cached] = ram_info();

        int perc = 100 * ((total - free) - (buffers + cached)) / total;

        std::string color = color_for(perc, {{{75, RED}, {50, ORANGE}, {0, GREEN}}});

        return fmt::format("M <fc={}>{}</fc>%", color, perc);
    }

    std::string swp_perc()
    {
        auto [total, free, cached] = swp_info();

        int perc = 100 * (total - free - cached) / total;
        std::string color = color_for(perc, {{{75, RED}, {50, ORANGE}, {0, GREEN}}});

        return fmt::format("S <fc={}>{}</fc>%", color, perc);
    }

    std::string ram_usage()
    {
        auto [total, free, avail, buffers, cached] = ram_info();
        int perc = 100 * ((total - free) - (buffers + cached)) / total;
        std::string color = color_for(perc, {{{75, RED}, {50, ORANGE}, {0, GREEN}}});
        return fmt::format("M <fc={}>{:.1f}</fc>/<fc=#8dc776>{:.1f}</fc> <fc=#b185db>GiB</fc>", color,
                           (total - free - buffers - cached) * 9.53674316e-7, total * 9.53674316e-7);
    }

    std::string swp_usage()
    {
        auto [total, free, cached] = swp_info();
        int perc = 100 * ((total - free) - (cached)) / total;
        std::string color = color_for(perc, {{{75, RED}, {50, ORANGE}, {0, GREEN}}});
        return fmt::format("S <fc={}>{:.1f}</fc>/<fc=#8dc776>{:.1f}</fc> <fc=#b185db>GiB</fc>", color, (total - free - cached) * 9.53674316e-7,
                           total * 9.53674316e-7);
    }

    std::string disk_usage()
    {
        struct statvfs fs;
        if (statvfs("/", &fs) < 0)
            return NA;

        int perc = (int)(100 * (1.0f - ((float)fs.f_bavail / (float)fs.f_blocks)));
        std::string color = color_for(perc, {{{75, RED}, {50, ORANGE}, {0, GREEN}}});

        double total = fs.f_frsize * fs.f_blocks * 9.3132257e-10;
        double used = fs.f_frsize * (fs.f_blocks - fs.f_bfree) * 9.3132257e-10;

        return fmt::format("D <fc={}>{}</fc>% <fc={}>{:.1f}</fc>/<fc=#8dc776>{:.1f}</fc> <fc=#b185db>GiB</fc>", color, perc, color, used, total);
    }
} // namespace
constexpr std::string (*top[])(){ram_perc, swp_perc, battery, audio, hostname};
constexpr std::string (*bot[])(){ram_usage, swp_usage, disk_usage, connection};

int main(int argc, char** argv)
{
    using namespace std::string_view_literals;
    if (argc != 2)
        err("args");

    if (argv[1] == "top"sv)
    {
        for (const auto& i : top)
        {
            fmt::print(" <fc=#51a39f>|</fc> {}", i());
        }
        return 0;
    }
    else
    {
        fmt::print("System Info (<fc=#8dc776>{}</fc>): [ ", exec("uname -r"));
        std::size_t idx = 0;
        for (const auto& i : bot)
        {
            if (idx + 1 != sizeof(bot) / sizeof(bot[0]))
            {
                fmt::print("{} <fc=#51a39f>|</fc> ", i());
            }
            else
            {
                fmt::print("{} ]", i());
            }
            idx++;
        }
        return 0;
    }
}
