// mock-data.jsx — Personale UI Kit mock data
// Exports: window.MOCK

const MOCK = {
  date: "Thursday, June 12, 2025",
  streak: 7,
  freshStart: "Fresh start at 8:00 AM",
  totalSeconds: 23520, // 6h 32m

  timeline: [
    { start: 8,    end: 9.5,  type: "Code",          label: "VS Code" },
    { start: 9.5,  end: 10,   type: "Communication",  label: "Slack" },
    { start: 10,   end: 12,   type: "Code",           label: "Cursor" },
    { start: 12,   end: 12.5, type: "Browsing",       label: "Chrome" },
    { start: 13,   end: 15,   type: "Code",           label: "VS Code" },
    { start: 15,   end: 15.5, type: "Design",         label: "Figma" },
    { start: 15.5, end: 16,   type: "Communication",  label: "Slack" },
    { start: 16,   end: 17,   type: "Writing",        label: "Notion" },
  ],

  categories: [
    { category: "Code",          percent: 63, totalSeconds: 14803, color: "#7c5cfc" },
    { category: "Communication", percent: 12, totalSeconds: 2822,  color: "#d64d8a" },
    { category: "Design",        percent: 8,  totalSeconds: 1882,  color: "#00ccbf" },
    { category: "Writing",       percent: 7,  totalSeconds: 1646,  color: "#35a882" },
    { category: "Browsing",      percent: 7,  totalSeconds: 1646,  color: "#f5a623" },
    { category: "Other",         percent: 3,  totalSeconds: 706,   color: "#3d4451" },
  ],

  apps: [
    { appName: "VS Code",  totalSeconds: 10800, percent: 50 },
    { appName: "Cursor",   totalSeconds: 3042,  percent: 13 },
    { appName: "Slack",    totalSeconds: 2822,  percent: 12 },
    { appName: "Figma",    totalSeconds: 1882,  percent: 8  },
    { appName: "Notion",   totalSeconds: 1646,  percent: 7  },
    { appName: "Chrome",   totalSeconds: 1176,  percent: 5  },
    { appName: "Terminal", totalSeconds: 706,   percent: 3  },
    { appName: "Arc",      totalSeconds: 470,   percent: 2  },
  ],

  sessions: [
    { id: 1, name: "Code", startTime: "08:00", endTime: "09:30", durationSeconds: 5400,
      apps: [{ appName: "VS Code", percent: 78 }, { appName: "Terminal", percent: 12 }, { appName: "Chrome", percent: 10 }] },
    { id: 2, name: "Code", startTime: "10:00", endTime: "12:00", durationSeconds: 7200,
      apps: [{ appName: "VS Code", percent: 82 }, { appName: "Cursor", percent: 18 }] },
    { id: 3, name: "Design", startTime: "15:00", endTime: "15:30", durationSeconds: 1800,
      apps: [{ appName: "Figma", percent: 100 }] },
    { id: 4, name: "Writing", startTime: "16:00", endTime: "17:00", durationSeconds: 3600,
      apps: [{ appName: "Notion", percent: 100 }] },
  ],

  websites: [
    { domain: "github.com",        category: "Code",     seconds: 3600 },
    { domain: "docs.swift.org",    category: "Code",     seconds: 1800 },
    { domain: "stackoverflow.com", category: "Code",     seconds: 1200 },
    { domain: "figma.com",         category: "Design",   seconds: 1882 },
    { domain: "notion.so",         category: "Writing",  seconds: 1646 },
    { domain: "linear.app",        category: "Code",     seconds: 900  },
    { domain: "youtube.com",       category: "Browsing", seconds: 470  },
  ],

  goals: [
    { category: "Code",    targetHours: 6,   currentHours: 4.1,  color: "#7c5cfc" },
    { category: "Design",  targetHours: 1,   currentHours: 0.52, color: "#00ccbf" },
    { category: "Writing", targetHours: 0.5, currentHours: 0.46, color: "#35a882" },
  ],

  pomodoroSessions: [
    { id: 1, goal: "Draft migration spec",  startTime: "08:00", durationSeconds: 1500, status: "completed" },
    { id: 2, goal: "Review open PRs",       startTime: "09:30", durationSeconds: 1800, status: "completed" },
    { id: 3, goal: "Debug auth flow",       startTime: "11:00", durationSeconds: 2100, status: "completed" },
    { id: 4, goal: "Write component docs",  startTime: "14:00", durationSeconds: 1500, status: "completed" },
  ],

  insights: {
    totalProductive: "4h 12m",
    totalTracked: "6h 32m",
    avgPerDay: "4h 8m",
    daysWithData: 28,
    avgSwitches: "24",
    totalSwitches: 672,
    bestDay: { label: "Wednesday", hours: "5h 30m" },
    peakHour: { label: "10:00 AM", hours: "1h 20m" },
    streaks: { current: 7, longest: 12, thresholdHours: 3 },
    dayOfWeek: [
      { label: "Mon", avgHours: 5.2 },
      { label: "Tue", avgHours: 6.1 },
      { label: "Wed", avgHours: 5.8 },
      { label: "Thu", avgHours: 4.9 },
      { label: "Fri", avgHours: 3.7 },
      { label: "Sat", avgHours: 1.2 },
      { label: "Sun", avgHours: 0.8 },
    ],
    trend: Array.from({ length: 28 }, (_, i) => ({
      label: `${i + 1}`,
      hours: Math.max(0.2, 4 + Math.sin(i * 0.4) * 1.5 + (i % 7 >= 5 ? -2.5 : 0) + (Math.random() - 0.5) * 0.5),
    })),
    heatmap: Array.from({ length: 7 }, (_, row) =>
      Array.from({ length: 24 }, (_, col) => {
        const isWeekday = row < 5;
        const isPeak = col >= 9 && col <= 12;
        const isWork = col >= 8 && col <= 18;
        if (isWeekday && isPeak) return 0.45 + (row * col * 7 % 11) / 20;
        if (isWeekday && isWork) return 0.15 + (row * col * 3 % 7) / 20;
        return (row * col % 5) / 40;
      })
    ),
  },
};

window.MOCK = MOCK;
