/**
 * {{product_name}} desktop plugin. Loaded uncompiled by Hermes Desktop —
 * UI is jsx()/jsxs() calls, not JSX syntax.
 * Only these imports resolve: @hermes/plugin-sdk, react, react/jsx-runtime.
 */

import { Button, Tip, cn, haptic } from '@hermes/plugin-sdk'
import { jsx, jsxs } from 'react/jsx-runtime'

const ID = 'pistisai'
const LOCAL_UI = 'http://127.0.0.1:1338'
const WEB_APP = '{{app_url}}'

function BrandPane({ ctx }) {
  return jsxs('div', {
    className: 'flex h-full flex-col gap-2 p-3 text-sm',
    children: [
      jsx('div', { className: 'font-medium', children: '{{product_name}}' }),
      jsx('div', {
        className: 'text-(--ui-text-tertiary)',
        children: `App UI: ${LOCAL_UI}`
      }),
      jsxs('div', {
        className: 'flex flex-col items-start gap-2',
        children: [
          jsx(Button, {
            type: 'button',
            onClick: () => {
              haptic('tap')
              void ctx.os.openExternal(LOCAL_UI)
            },
            children: 'Open in Browser'
          }),
          jsx(Button, {
            type: 'button',
            variant: 'secondary',
            onClick: () => {
              haptic('tap')
              void ctx.os.openExternal(WEB_APP)
            },
            children: 'Open Web App'
          })
        ]
      })
    ]
  })
}

function BrandChip() {
  return jsx(Tip, {
    label: '{{product_name}}',
    children: jsx('button', {
      className: cn(
        'inline-flex h-full items-center gap-1 px-1.5 text-[0.6875rem] transition-colors',
        'text-(--ui-text-tertiary) hover:bg-(--chrome-action-hover) hover:text-foreground'
      ),
      type: 'button',
      children: '{{product_name}}'
    })
  })
}

export default {
  id: ID,
  name: '{{product_name}}',
  register(ctx) {
    ctx.register({
      id: 'pane',
      area: 'panes',
      title: '{{product_name}}',
      data: { placement: 'right', width: '300px' },
      render: () => jsx(BrandPane, { ctx })
    })

    ctx.register({
      id: 'chip',
      area: 'statusBar.right',
      order: 130,
      render: () => jsx(BrandChip, {})
    })
  }
}
