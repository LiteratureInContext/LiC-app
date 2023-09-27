/* global cy */
describe('The landing page', function () {
  it('should load ', function () {
    cy.visit('/exist/apps/LiC/index.html')
      .get('.alert')
      .contains('app.xqm')
  })


  // TODO: add more mysec tests, broken upstream
  it.skip('navbar link should forward to admin page', function () {
    cy.get()
  })

  // TODO: The navbar should have uniform background color
  it.skip('navbar should render properly', function () {
    cy.get()
  })
  })
