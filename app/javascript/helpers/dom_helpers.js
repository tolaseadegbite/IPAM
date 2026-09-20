// DOM fragment helpers for paginated history.
// Ported from Campfire's dom_helpers.
export function parseHTMLFragment(html) {
  const template = document.createElement("template")
  template.innerHTML = html
  return template.content
}

export function insertHTMLFragment(fragment, container, top) {
  if (top) {
    container.prepend(fragment)
  } else {
    container.append(fragment)
  }
}

export function trimChildren(count, container, top, rowSelector) {
  const rows = Array.from(container.querySelectorAll(rowSelector))
  const elements = top ? rows.slice(0, count) : rows.slice(-count)

  keepScroll(container, top, function() {
    for (const element of elements) {
      element.remove()
    }
  })
}

export async function keepScroll(container, top, fn) {
  pauseInertiaScroll(container)

  const scrollTop = container.scrollTop
  const scrollHeight = container.scrollHeight

  await fn()

  if (top) {
    container.scrollTop = scrollTop + (container.scrollHeight - scrollHeight)
  } else {
    container.scrollTop = scrollTop
  }
}

function pauseInertiaScroll(container) {
  container.style.overflow = "hidden"

  requestAnimationFrame(() => {
    container.style.overflow = ""
  })
}
