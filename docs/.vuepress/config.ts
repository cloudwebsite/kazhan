import type { SidebarConfig } from 'vuepress'
import { defineUserConfig } from 'vuepress'
import { viteBundler } from '@vuepress/bundler-vite'
import { defaultTheme } from '@vuepress/theme-default'
import { searchPlugin } from '@vuepress/plugin-search'
import { shikiPlugin } from '@vuepress/plugin-shiki'

const guideChildren = [
  { text: '部署指南', link: '/guide/deploy.html' },
  { text: '装完先配这些', link: '/guide/first-config.html' },
  { text: '后台菜单对照', link: '/guide/admin-map.html' },
  { text: '系统设置全览', link: '/guide/settings.html' },
  { text: '同机多站点', link: '/guide/multi-site.html' },
  { text: '货源导入任务', link: '/guide/import-tasks.html' },
  { text: '产品命名', link: '/guide/naming.html' },
]

const featureChildren = [
  { text: '运营概览', link: '/features/dashboard.html' },
  { text: '商品、分类与卡密', link: '/features/commerce.html' },
  { text: '订单处理', link: '/features/orders.html' },
  { text: '会员与钱包', link: '/features/members.html' },
  { text: '内容管理', link: '/features/content.html' },
  { text: '营销功能', link: '/features/marketing.html' },
  { text: '货源对接', link: '/features/supply.html' },
  { text: '工单管理', link: '/features/tickets.html' },
  { text: '员工与权限', link: '/features/staff.html' },
  { text: '分站（白标）', link: '/features/subsite.html' },
  { text: '会员抽奖', link: '/features/lottery.html' },
  { text: '导入分类与复用发货', link: '/features/product-import-category.html' },
  { text: '商城首屏加载', link: '/features/storefront-startup-recovery.html' },
  { text: 'ACG 货源兼容', link: '/features/acg-legacy-import-compatibility.html' },
]

const paymentChildren = [
  { text: '支付总览', link: '/payment/' },
  { text: '渠道字段手册', link: '/payment/channels.html' },
  { text: '虎皮椒 XunhuPay', link: '/payment/payment-xunhupay.html' },
  { text: 'UPay Pro', link: '/payment/payment-upay-pro.html' },
]

const themeChildren = [
  { text: '主题概览', link: '/themes/' },
  { text: '主题设置', link: '/themes/settings.html' },
]

const opsChildren = [
  { text: '在线更新与回滚', link: '/operations/update.html' },
  { text: '备份与密钥', link: '/operations/backup.html' },
  { text: '两步验证与账号恢复', link: '/operations/security-2fa.html' },
  { text: '低库存监控', link: '/operations/low-stock-monitor.html' },
]

const guideSidebar: SidebarConfig = [{ text: '快速上手', children: guideChildren }]
const featureSidebar: SidebarConfig = [{ text: '功能说明', children: featureChildren }]
const paymentSidebar: SidebarConfig = [{ text: '支付', children: paymentChildren }]
const themeSidebar: SidebarConfig = [{ text: '主题', children: themeChildren }]
const opsSidebar: SidebarConfig = [{ text: '运维', children: opsChildren }]

export default defineUserConfig({
  base: '/kazhan/',
  bundler: viteBundler(),
  lang: 'zh-CN',
  title: '卡栈',
  description: '卡栈文档 — 部署、系统设置、功能、支付、主题与运维',
  head: [
    ['link', { rel: 'icon', href: '/logo.svg' }],
    ['meta', { name: 'theme-color', content: '#0f766e' }],
  ],

  plugins: [
    shikiPlugin({
      themes: {
        light: 'min-light',
        dark: 'github-dark',
      },
      lineNumbers: false,
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
      { text: '快速上手', children: guideChildren },
      { text: '功能', children: featureChildren },
      { text: '支付', children: paymentChildren },
      { text: '主题', children: themeChildren },
      { text: '运维', children: opsChildren },
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
        { text: '快速上手', children: guideChildren },
        { text: '功能', children: featureChildren },
        { text: '支付', children: paymentChildren },
        {
          text: '主题与运维',
          children: [...themeChildren, ...opsChildren],
        },
        { text: '更新日志', link: '/changelog/' },
      ],
    },
    sidebarDepth: 2,
  }),
})
