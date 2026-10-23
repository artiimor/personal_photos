import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "filename"]

  highlight() {
    this.element.classList.add("border-green-600", "bg-green-50")
  }

  unhighlight() {
    this.element.classList.remove("border-green-600", "bg-green-50")
  }

  change() {
    const file = this.inputTarget.files[0]
    this.filenameTarget.textContent = file ? file.name : ""
    this.filenameTarget.classList.toggle("hidden", !file)
  }
}
