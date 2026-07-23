import { Controller } from "@hotwired/stimulus"

// Looks up an existing record (driver by cpf, truck by plate) as soon as the
// operator tabs out of the query field, and fills in the other fields when found.
// While the request is in flight, every field and the submit button in the form
// are disabled and the spinner target (if present) is shown, so the operator can't
// change anything or submit before the autofill has settled.
export default class extends Controller {
  static targets = ["query", "fillable", "spinner"]
  static values = { url: String, param: String }

  async lookup() {
    const query = this.queryTarget.value.trim()
    if (!query) return

    this.setLoading(true)

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set(this.paramValue, query)

      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (!response.ok) return

      const data = await response.json()
      if (!data.found) return

      this.fillableTargets.forEach((field) => {
        const key = field.dataset.lookupField
        if (key && data.record[key] !== undefined && data.record[key] !== null) {
          field.value = data.record[key]
        }
      })
    } finally {
      this.setLoading(false)
    }
  }

  setLoading(isLoading) {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.hidden = !isLoading
    }

    const form = this.element.closest("form")
    form?.querySelectorAll("input, select, textarea, button").forEach((field) => {
      field.disabled = isLoading
    })
  }
}
