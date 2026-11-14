import type { SidebarConfig } from 'vuepress'
import { defineUserConfig } from 'vuepress'
import { viteBundler } from '@vuepress/bundler-vite'
import { defaultTheme } from '@vuepress/theme-default'
import { searchPlugin } from '@vuepress/plugin-search'
import { shikiPlugin } from '@vuepress/plugin-shiki'

const guideSidebar: SidebarConfig = [
  {
    text: '快速上手',
    children: [
      { text: '部署指南', link: '/guide/deploy.html' },
      { text: '产品命名', link: '/guide/naming.html' },
      { text: '导入任务', link: '/guide/import-tasks.html' },
    ],
  },
]

const featureSidebar: SidebarConfig = [
  {
    text: '功能说明',
    children: [
      { text: '会员抽奖', link: '/features/lottery.html' },
      { text: '商品导入分类与复用发货', link: '/features/product-import-category.html' },
      { text: '前台启动恢复', link: '/features/storefront-startup-recovery.html' },
      { text: 'ACG 历史导入兼容', link: '/features/acg-legacy-import-compatibility.html' },
    ],
  },
]

const paymentSidebar: SidebarConfig = [
  {
    text: '支付',
    children: [
      { text: '虎皮椒 XunhuPay', link: '/payment/payment-xunhupay.html' },
      { text: 'UPay Pro', link: '/payment/payment-upay-pro.html' },
    ],
  },
]

const themeSidebar: SidebarConfig = [
  {
    text: '主题',
    children: [
      { text: '主题概览', link: '/themes/' },
      { text: '主题设置', link: '/themes/settings.html' },
    ],
  },
]

const opsSidebar: SidebarConfig = [
  {
    text: '运维',
    children: [
      { text: '低库存监控', link: '/operations/low-stock-monitor.html' },
    ],
  },
]

export default defineUserConfig({
  base: '/kazhan/',
  bundler: viteBundler(),
  lang: 'zh-CN',
  title: '卡栈',
  description: '卡栈文档 — 部署、功能、支付、主题、运维与更新日志',
  head: [
    ['link', { rel: 'icon', href: '/logo.svg' }],
    ['meta', { name: 'theme-color', content: '#0f766e' }],
  ],

  plugins: [
    shikiPlugin({
      themes: {
        light: 'github-light',
        dark: 'github-dark',
      },
    }),
    searchPlugin({}),
  ],

  theme: defaultTheme({
    logo: '/logo.svg',
    repo: 'cloudwebsite/kazhan',
    repoLabel: 'GitHub',
    docsRepo: 'https://github.com/cloudwebsite/kazhan',
    docsBranch: 'main',
    docsDir: 'docs',
    editLink: true,
    editLinkText: '在 GitHub 上编辑此页',
    lastUpdated: true,
    lastUpdatedText: '最后更新',
    contributors: false,

    navbar: [
      { text: '首页', link: '/' },
      { text: '快速上手', link: '/guide/deploy.html' },
      {
        text: '功能',
        children: [
          { text: '会员抽奖', link: '/features/lottery.html' },
          { text: '商品导入分类与复用发货', link: '/features/product-import-category.html' },
          { text: '前台启动恢复', link: '/features/storefront-startup-recovery.html' },
          { text: 'ACG 历史导入兼容', link: '/features/acg-legacy-import-compatibility.html' },
        ],
      },
      {
        text: '支付',
        children: [
          { text: '虎皮椒 XunhuPay', link: '/payment/payment-xunhupay.html' },
          { text: 'UPay Pro', link: '/payment/payment-upay-pro.html' },
        ],
      },
      {
        text: '主题',
        children: [
          { text: '主题概览', link: '/themes/' },
          { text: '主题设置', link: '/themes/settings.html' },
        ],
      },
      { text: '运维', link: '/operations/low-stock-monitor.html' },
      { text: '更新日志', link: '/changelog/' },
    ],

    sidebar: {
      '/guide/': guideSidebar,
      '/features/': featureSidebar,
      '/payment/': paymentSidebar,
      '/themes/': themeSidebar,
      '/operations/': opsSidebar,
      '/changelog/': [{ text: '更新日志', link: '/changelog/' }],
      '/releases/': [{ text: '更新日志', link: '/changelog/' }],
      '/': [
        { text: '首页', link: '/' },
        {
          text: '快速上手',
          children: [
            { text: '部署指南', link: '/guide/deploy.html' },
            { text: '产品命名', link: '/guide/naming.html' },
            { text: '导入任务', link: '/guide/import-tasks.html' },
          ],
        },
        {
          text: '功能',
          children: [
            { text: '会员抽奖', link: '/features/lottery.html' },
            { text: '商品导入分类与复用发货', link: '/features/product-import-category.html' },
            { text: '前台启动恢复', link: '/features/storefront-startup-recovery.html' },
            { text: 'ACG 历史导入兼容', link: '/features/acg-legacy-import-compatibility.html' },
          ],
        },
        {
          text: '支付',
          children: [
            { text: '虎皮椒 XunhuPay', link: '/payment/payment-xunhupay.html' },
            { text: 'UPay Pro', link: '/payment/payment-upay-pro.html' },
          ],
        },
        {
          text: '主题与运维',
          children: [
            { text: '主题概览', link: '/themes/' },
            { text: '主题设置', link: '/themes/settings.html' },
            { text: '低库存监控', link: '/operations/low-stock-monitor.html' },
          ],
        },
        { text: '更新日志', link: '/changelog/' },
      ],
    },
    sidebarDepth: 2,
  }),
})
