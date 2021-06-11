import unittest
import os
import traceback
from multiprocessing import Value
import nose2
import time


from functions.Functions import click_js
from functions.Functions import create_firefoxdriver
from functions.Functions import create_chromedriver
from functions.Functions import fill_element
from functions.Functions import scroll_to_element
from functions.Functions import wait_for_invisibility
from functions.Collections import login_panel
from functions.Collections import logout_panel
from functions.Collections import create_reseller
from functions.Collections import create_reseller_contract
from functions.Collections import create_billing_profile
from functions.Collections import delete_reseller
from functions.Collections import delete_reseller_contract
from functions.Collections import delete_billing_profile
import selenium.common.exceptions
from selenium import webdriver
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.desired_capabilities import DesiredCapabilities
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.by import By
from datetime import datetime
import random

filename = 0
browser = ""


class testrun(unittest.TestCase):

    def setUp(self):
        if browser == "firefox":
            self.driver = create_firefoxdriver()
        elif browser == "chrome":
            self.driver = create_chromedriver()
        self.longMessage = True

    def test_admin(self):
        global filename
        adminname = "admin" + str(random.randint(1, 99999))
        resellername = "reseller" + str(random.randint(1, 99999))
        resellercontract = "contract" + str(random.randint(1, 99999))
        email = "test" + str(random.randint(1, 99999)) + "@test.com"
        filename = "test_admin.png"
        driver = self.driver
        login_panel(driver)
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Settings")]').click()
        create_reseller_contract(driver, resellercontract)
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        create_reseller(driver, resellername, resellercontract)
        print("Go to 'Administrators'...", end="")
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Administrators")]').click()
        print("OK")
        print("Try to create a new Administrator...", end="")
        click_js(driver, '//*[@id="q-app"]/div//main//div/a[contains(., "add")]')
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Reseller")]/../div/input', resellername)
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        driver.find_element_by_xpath('/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Login")]/../div/input', adminname)
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Email")]/../div/input', email)
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//input[@aria-label="Password"]', 'administrato')
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//input[@aria-label="Password Retype"]', 'administrato')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main/div//button[contains(., "Save")]').click()
        print("OK")
        print("Check if Administrator was created...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', adminname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main/div//table/tbody/tr[1]/td[contains(., "' + adminname + '")]')) > 0, "Administrator was not found")
        print("OK")
        print("Try to log-in with new Administrator...", end="")
        logout_panel(driver)
        login_panel(driver, adminname, 'administrato')
        print("OK")
        print("Go back to administrator login", end="")
        logout_panel(driver)
        login_panel(driver)
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Settings")]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Administrators")]').click()
        print("OK")
        print("Try to enable 'Read only' for administrator...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', adminname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main/div//table/tbody/tr[1]/td[contains(., "' + adminname + '")]')) > 0, "Administrator was not found")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table//tr[1]/td[9]/div').click()
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        print("OK")
        print("Check if 'Read-only' was enabled...", end="")
        logout_panel(driver)
        login_panel(driver, adminname, 'administrato')
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Settings")]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Customers")]').click()
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        driver.implicitly_wait(1)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main//div/a[contains(., "Add")]')) == 0, "'Add' Button is still there")
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Contacts")]').click()
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        driver.implicitly_wait(1)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main//div/a[contains(., "Add")]')) == 0, "'Add' Button is still there")
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Domains")]').click()
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        driver.implicitly_wait(1)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main//div/a[contains(., "Add")]')) == 0, "'Add' Button is still there")
        driver.implicitly_wait(10)
        print("OK")
        print("Go back to administrator login", end="")
        logout_panel(driver)
        login_panel(driver)
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Settings")]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Administrators")]').click()
        print("OK")
        print("Try to deactivate administrator...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', adminname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main/div//table/tbody/tr[1]/td[contains(., "' + adminname + '")]')) > 0, "Administrator was not found")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table//tr[1]/td[8]/div').click()
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        print("OK")
        print("Check if admin was deactivated...", end="")
        logout_panel(driver)
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '//*[@aria-label="Username"]')))
        fill_element(driver, '//*[@aria-label="Username"]', 'invalid')
        fill_element(driver, '//*[@aria-label="Password"]', 'data')
        click_js(driver, '//*[@id="q-app"]/div//main/div/form//button[contains(., "Sign In")]')
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div[contains(., "Wrong credentials")]')) > 0, "Admin was not deactivated")
        print("OK")
        print("Try to delete administrator...", end="")
        login_panel(driver)
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Settings")]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Administrators")]').click()
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', adminname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main/div//table/tbody/tr[1]/td[contains(., "' + adminname + '")]')) > 0, "Administrator was not found")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[16]/button').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div/div')))
        driver.find_element_by_xpath('/html/body/div[4]/div/div').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div[2]/div/div[3]/button[2]')))
        driver.find_element_by_xpath('/html/body/div[4]/div[2]/div/div[3]/button[2]').click()
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        fill_element(driver, '/html/body//div/main//div/label//div/input', adminname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//i')) > 0, "Admin was not deleted")
        print("OK")
        delete_reseller(driver, resellername)
        filename = 0

    """
    def test_billing_profile(self):
        global filename
        billingname = "billing" + str(random.randint(1, 99999))
        billingrealname = "name" + str(random.randint(1, 99999))
        resellername = "reseller" + str(random.randint(1, 99999))
        resellercontract = "contract" + str(random.randint(1, 99999))
        filename = "test_billing_profile.png"
        driver = self.driver
        login_panel(driver)
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Settings")]').click()
        create_reseller_contract(driver, resellercontract)
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        create_reseller(driver, resellername, resellercontract)
        print("Go to 'Billing Profiles'...", end="")
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Billing Profiles")]').click()
        print("OK")
        print("Try to create a new Billing Profile...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/a[contains(., "add")]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Reseller")]/../div/input', resellername)
        driver.find_element_by_xpath('/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Handle")]/../div/input', billingname)
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Name")]/../div/input', billingrealname)
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main/div//button[contains(., "Save")]').click()
        print("OK")
        print("Check if Billing Profile was created...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', billingrealname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main/div//table/tbody/tr[1]/td[contains(., "' + billingrealname + '")]')) > 0, "Billing Profile was not found")
        print("OK")
        print("Try to delete Billing Profile...", end="")
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '//*[@id="q-app"]/div//main/div//table/tbody/tr[1]/td[7]/button')))
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main/div//table/tbody/tr[1]/td[7]/button').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div/div[2]')))
        driver.find_element_by_xpath('/html/body/div[4]/div/div[2]').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div[2]/div/div[3]/button[2]')))
        driver.find_element_by_xpath('/html/body/div[4]/div[2]/div/div[3]/button[2]').click()
        print("OK")
        print("Check if Billing Profile was deleted...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        fill_element(driver, '/html/body//div/main//div/label//div/input', billingrealname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//i')) > 0, "Billing Profile was not deleted")
        print("OK")
        delete_reseller(driver, resellername)
        filename = 0
    """

    def test_contacts(self):
        global filename
        contactmail = "contact" + str(random.randint(1, 99999)) + "@test.inv"
        firstname = "first" + str(random.randint(1, 99999))
        lasttname = "last" + str(random.randint(1, 99999))
        filename = "test_contact.png"
        driver = self.driver
        login_panel(driver)
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Settings")]').click()
        print("Go to 'Contacts'...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Contacts")]').click()
        print("OK")
        print("Try to create a new customer contact with an invalid Email...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/button[contains(., "Add")]').click()
        driver.find_element_by_xpath('/html/body//div[@class="q-list"]/a[1]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Reseller")]/../div/input', "default")
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Email")]/../div/input', "invaildmail")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main/div//button[contains(., "Save")]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div/main/form//div/label//div[contains(., "Input must be")]')) > 0)
        print("OK")
        print("Try to create a new customer contact...", end="")
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Email")]/../div/input', contactmail)
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main/div//button[contains(., "Save")]').click()
        print("OK")
        print("Check if customer contact was created...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', contactmail)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main/div//table/tbody/tr[1]/td[contains(., "' + contactmail + '")]')) > 0, "Contact was not found")
        print("OK")
        print("Try to add first and last name to contact...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/table/tbody/tr[1]/td[4]/span').click()
        fill_element(driver, '/html/body//div//label//div//input[@aria-label="First Name"]', firstname)
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        driver.find_element_by_xpath('/html/body//div/button[contains(., "Save")]').click()
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//table/tbody/tr[1]/td[contains(., "' + firstname + '")]')) > 0, "Contact first name was not changed")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/table/tbody/tr[1]/td[5]/span').click()
        fill_element(driver, '/html/body//div//label//div//input[@aria-label="Last Name"]', lasttname)
        driver.find_element_by_xpath('/html/body//div/button[contains(., "Save")]').click()
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', lasttname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//table/tbody/tr[1]/td[contains(., "' + lasttname + '")]')) > 0, "Contact last name was not changed")
        print("OK")
        print("Try to delete contact...", end="")
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[8]/button').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div/div')))
        driver.find_element_by_xpath('/html/body/div[4]/div/div').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div[2]/div/div[3]/button[2]')))
        driver.find_element_by_xpath('/html/body/div[4]/div[2]/div/div[3]/button[2]').click()
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        fill_element(driver, '/html/body//div/main//div/label//div/input', contactmail)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//i')) > 0, "Contact was not deleted")
        print("OK")
        print("Try to create a new system contact with an invalid Email...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/button[contains(., "Add")]').click()
        driver.find_element_by_xpath('/html/body//div[@class="q-list"]/a[2]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Email")]/../div/input', "invaildmail")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main/div//button[contains(., "Save")]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div/main/form//div/label//div[contains(., "Input must be")]')) > 0)
        print("OK")
        print("Try to create a new system contact...", end="")
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Email")]/../div/input', contactmail)
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main/div//button[contains(., "Save")]').click()
        print("OK")
        print("Check if system contact was created...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', contactmail)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main/div//table/tbody/tr[1]/td[contains(., "' + contactmail + '")]')) > 0, "Contact was not found")
        print("OK")
        print("Try to add first and last name to contact...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/table/tbody/tr[1]/td[4]/span').click()
        fill_element(driver, '/html/body//div//label//div//input[@aria-label="First Name"]', firstname)
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        driver.find_element_by_xpath('/html/body//div/button[contains(., "Save")]').click()
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//table/tbody/tr[1]/td[contains(., "' + firstname + '")]')) > 0, "Contact first name was not changed")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/table/tbody/tr[1]/td[5]/span').click()
        fill_element(driver, '/html/body//div//label//div//input[@aria-label="Last Name"]', lasttname)
        driver.find_element_by_xpath('/html/body//div/button[contains(., "Save")]').click()
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', lasttname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//table/tbody/tr[1]/td[contains(., "' + lasttname + '")]')) > 0, "Contact last name was not changed")
        print("OK")
        print("Try to edit and reset edits to system contact...", end="")
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[8]/button').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body//div/a[contains(., "Edit")]')))
        driver.find_element_by_xpath('/html/body//div/a[contains(., "Edit")]').click()
        fill_element(driver, '//*[@id="q-app"]//div/main//form//div/label//div/input[@aria-label="Company"]', contactmail)
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main//form/div/div[1]/div/div[4]/div/label/div/div/div[2]/button').click()
        self.assertTrue(
            driver.find_element_by_xpath('//*[@id="q-app"]//div/main//form//div/label//div/input[@aria-label="Company"]').get_attribute('value') == '', 'Saved value is not correct')
        print("OK")
        filename = 0

    def test_contracts(self):
        global filename
        contractname = "customer" + str(random.randint(1, 99999))
        filename = "test_contracts.png"
        driver = self.driver
        login_panel(driver)
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Settings")]').click()
        print("Go to 'Contracts'...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Contracts")]').click()
        print("OK")
        print("Try to create a new peering contract...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/button[contains(., "Add")]').click()
        driver.find_element_by_xpath('/html/body//div[@class="q-list"]/a[1]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Contact")]/../div/input', "default")
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        wait_for_invisibility(driver, '/html/body//div[@class="q-virtual-scroll__content"]/div[1]')
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main/form//div//label[contains(., "Status")]').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "External")]/../div/input', contractname)
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main/form//div//label[contains(., "Billing Profile")]').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/button[contains(., "Save")]').click()
        print("OK")
        print("Check if contract has been created...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', contractname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//table/tbody/tr[1]/td[contains(., "' + contractname + '")]')) > 0, "Reseller was not found")
        print("OK")
        print("Try to edit contract status...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[7]/span').click()
        driver.find_element_by_xpath('/html/body//div[@class="q-item__label"][contains(., "Locked")]').click()
        wait_for_invisibility(driver, '/html/body//div[@class="q-virtual-scroll__content"]')
        driver.find_element_by_xpath('/html/body//div/button[contains(., "Save")]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[7]/span[contains(., "Locked")]')) > 0, "Subscriber status was not edited")
        print("OK")
        print("Try to delete contract...", end="")
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[8]/button').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div/div')))
        driver.find_element_by_xpath('/html/body/div[4]/div/div').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div[2]/div/div[3]/button[2]')))
        driver.find_element_by_xpath('/html/body/div[4]/div[2]/div/div[3]/button[2]').click()
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        fill_element(driver, '/html/body//div/main//div/label//div/input', contractname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//i')) > 0, "Contact was not deleted")
        print("OK")
        print("Try to create a new reseller contract...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/button[contains(., "Add")]').click()
        driver.find_element_by_xpath('/html/body//div[@class="q-list"]/a[2]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Contact")]/../div/input', "default")
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        wait_for_invisibility(driver, '/html/body//div[@class="q-virtual-scroll__content"]/div[1]')
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main/form//div//label[contains(., "Status")]').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "External")]/../div/input', contractname)
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main/form//div//label[contains(., "Billing Profile")]').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/button[contains(., "Save")]').click()
        print("OK")
        print("Check if contract has been created...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', contractname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//table/tbody/tr[1]/td[contains(., "' + contractname + '")]')) > 0, "Reseller was not found")
        print("OK")
        print("Try to edit contract status...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[7]/span').click()
        driver.find_element_by_xpath('/html/body//div[@class="q-item__label"][contains(., "Locked")]').click()
        wait_for_invisibility(driver, '/html/body//div[@class="q-virtual-scroll__content"]')
        driver.find_element_by_xpath('/html/body//div/button[contains(., "Save")]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[7]/span[contains(., "Locked")]')) > 0, "Subscriber status was not edited")
        print("OK")
        print("Try to delete contract...", end="")
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[8]/button').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div/div')))
        driver.find_element_by_xpath('/html/body/div[4]/div/div').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div[2]/div/div[3]/button[2]')))
        driver.find_element_by_xpath('/html/body/div[4]/div[2]/div/div[3]/button[2]').click()
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        fill_element(driver, '/html/body//div/main//div/label//div/input', contractname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//i')) > 0, "Contract was not deleted")
        print("OK")
        filename = 0

    def test_customer(self):
        global filename
        customername = "customer" + str(random.randint(1, 99999))
        filename = "test_customer.png"
        driver = self.driver
        login_panel(driver)
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Settings")]').click()
        print("Go to 'Customers'...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Customers")]').click()
        print("OK")
        print("Try to create a new customer...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/a[contains(., "Add")]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Contact")]/../div/input', "default")
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]/div/div[2]/main/form/div/div[2]/div[1]/div[2]/div/label/div[1]').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main/form//div//label[contains(., "Status")]').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "External")]/../div/input', customername)
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/button[contains(., "Save")]').click()
        print("OK")
        print("Check if customer has been created...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', customername)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//table/tbody/tr[1]/td[contains(., "' + customername + '")]')) > 0, "Reseller was not found")
        print("OK")
        print("Try to edit customer status...", end="")
        scroll_to_element(driver, '//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[9]/span')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[9]/span').click()
        driver.implicitly_wait(1)
        if len(driver.find_elements_by_xpath('/html/body//div[@class="q-item__label"][contains(., "Locked")]')) == 0:
            driver.find_element_by_xpath('/html/body/div[4]/label').click()
        driver.implicitly_wait(10)
        driver.find_element_by_xpath('/html/body//div[@class="q-item__label"][contains(., "Locked")]').click()
        wait_for_invisibility(driver, '/html/body//div[@class="q-virtual-scroll__content"]')
        driver.find_element_by_xpath('/html/body//div/button[contains(., "Save")]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[9]/span[contains(., "Locked")]')) > 0, "Subscriber status was not edited")
        print("OK")
        print("Go to customer preferences...", end="")
        scroll_to_element(driver, '//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[11]/button')
        click_js(driver, '//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[11]/button')
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body//div/a[contains(., "Preferences")]')))
        driver.find_element_by_xpath('/html/body//div/a[contains(., "Preferences")]').click()
        print("OK")
        print("Try to change a setting (concurrent_max)...", end="")
        fill_element(driver, '/html/body//div//main//div//label//div/input[@aria-label="Maximum number of concurrent calls"]', 100)
        driver.find_element_by_xpath('/html/body//div//main//div//label//div//button[contains(., "Save")]').click()
        wait_for_invisibility(driver, '/html/body//div//main//div//label//div/svg[@class="q-spinner q-spinner-mat"]')
        self.assertTrue(
            driver.find_element_by_xpath('/html/body//div//main//div//label//div/input[@aria-label="Maximum number of concurrent calls"]').get_attribute('value') == '100',
            'Saved value is not correct')
        print("OK")
        print("Try to delete setting value and restoring it...", end="")
        driver.find_element_by_xpath('/html/body//div//main//div//label//div/button[contains(., "cancel")]').click()
        driver.find_element_by_xpath('/html/body//div//main//div//label//div//button[contains(., "Reset")]').click()
        wait_for_invisibility(driver, '/html/body//div//main//div//label//div/svg[@class="q-spinner q-spinner-mat"]')
        self.assertTrue(
            driver.find_element_by_xpath('/html/body//div//main//div//label//div/input[@aria-label="Maximum number of concurrent calls"]').get_attribute('value') == '100',
            'Saved value is not correct')
        print("OK")
        print("Try to delete setting...", end="")
        driver.find_element_by_xpath('/html/body//div//main//div//label//div/button[contains(., "cancel")]').click()
        driver.find_element_by_xpath('/html/body//div//main//div//label//div//button[contains(., "Save")]').click()
        wait_for_invisibility(driver, '/html/body//div//main//div//label//div/svg[@class="q-spinner q-spinner-mat"]')
        self.assertTrue(
            driver.find_element_by_xpath('/html/body//div//main//div//label//div/input[@aria-label="Maximum number of concurrent calls"]').get_attribute('value') == '', 'Saved value is not correct')
        print("OK")
        print("Try to delete customer...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Customers")]').click()
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', customername)
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '//*[@id="q-app"]//div//main//div//table/tbody/tr[1]/td[contains(., "' + customername + '")]')))
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[11]/button').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div/div')))
        driver.find_element_by_xpath('/html/body/div[4]/div/div').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div[2]/div/div[3]/button[2]')))
        driver.find_element_by_xpath('/html/body/div[4]/div[2]/div/div[3]/button[2]').click()
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        fill_element(driver, '/html/body//div/main//div/label//div/input', customername)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//i')) > 0, "Reseller was not deleted")
        print("OK")
        filename = 0

    def test_domain(self):
        global filename
        domainname = "domain" + str(random.randint(1, 99999))
        filename = "test_domain.png"
        driver = self.driver
        login_panel(driver)
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Settings")]').click()
        print("Go to 'Domains'...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Domains")]').click()
        print("OK")
        print("Try to create a new domain...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/a[contains(., "add")]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Reseller")]/../div/input', 'default')
        driver.find_element_by_xpath('/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Domain")]/../div/input', domainname)
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main/div//button[contains(., "Save")]').click()
        print("OK")
        print("Check if domain was created...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', domainname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main/div//table/tbody/tr[1]/td[contains(., "' + domainname + '")]')) > 0, "Billing Profile was not found")
        print("OK")
        print("Try to open the domain preferences page...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[5]/button').click()
        WebDriverWait(driver, 10.).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/a[contains(., "Preferences")]')))
        driver.find_element_by_xpath('/html/body//div/a[contains(., "Preferences")]').click()
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div[@role="progressbar"]')
        print("OK")
        print("Try to change a setting (allowed_ips) with an invalid value...", end="")
        fill_element(driver, '/html/body//div//main//div//label//div/input[@aria-label="Allowed source IPs"]', 'invalid')
        driver.find_element_by_xpath('/html/body//div//main//div//label//div//button[contains(., "Save")]').click()
        wait_for_invisibility(driver, '/html/body//div//main//div//label//div/svg[@class="q-spinner q-spinner-mat"]')
        self.assertTrue(
            len(driver.find_elements_by_xpath('/html/body//div//main//div//label//div//button[contains(., "Save")]')) > 0, "Incorrect value was saved")
        print("OK")
        print("Try to change a setting (allowed_ips) with a valid value...", end="")
        fill_element(driver, '/html/body//div//main//div//label//div/input[@aria-label="Allowed source IPs"]', '10.0.0.0')
        driver.find_element_by_xpath('/html/body//div//main//div//label//div//button[contains(., "Save")]').click()
        wait_for_invisibility(driver, '/html/body//div//main//div//label//div/svg[@class="q-spinner q-spinner-mat"]')
        self.assertTrue(
            driver.find_element_by_xpath('/html/body//div//main//div//label//div/input[@aria-label="Allowed source IPs"]').get_attribute('value') == '10.0.0.0', 'Saved value is not correct')
        print("OK")
        print("Try to delete setting value and restoring it...", end="")
        driver.find_element_by_xpath('/html/body//div//main//div//label//div/button[contains(., "cancel")]').click()
        driver.find_element_by_xpath('/html/body//div//main//div//label//div//button[contains(., "Reset")]').click()
        wait_for_invisibility(driver, '/html/body//div//main//div//label//div/svg[@class="q-spinner q-spinner-mat"]')
        self.assertTrue(
            driver.find_element_by_xpath('/html/body//div//main//div//label//div/input[@aria-label="Allowed source IPs"]').get_attribute('value') == '', 'Saved value is not correct')
        print("OK")
        """
        print("Try to delete setting...", end="")
        driver.find_element_by_xpath('/html/body//div//main//div//label//div/button[contains(., "cancel")]').click()
        driver.find_element_by_xpath('/html/body//div//main//div//label//div//button[contains(., "Save")]').click()
        wait_for_invisibility(driver, '/html/body//div//main//div//label//div/svg[@class="q-spinner q-spinner-mat"]')
        self.assertTrue(
            driver.find_element_by_xpath('/html/body//div//main//div//label//div/input[@aria-label="Allowed source IPs"]').get_attribute('value') == '', 'Saved value is not correct')
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Domains")]').click()
        print("OK")
        """
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Domains")]').click()
        print("Try to delete domain...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', domainname)
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '//*[@id="q-app"]//div/main//div/table/tbody/tr[1]/td[5]/button')))
        driver.find_element_by_xpath('//*[@id="q-app"]//div/main//div/table/tbody/tr[1]/td[5]/button').click()
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body/div[4]/div/div')))
        driver.find_element_by_xpath('/html/body/div[4]/div/div').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div[2]/div/div[3]/button[2]')))
        driver.find_element_by_xpath('/html/body/div[4]/div[2]/div/div[3]/button[2]').click()
        print("OK")
        print("Check if domain was deleted...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        fill_element(driver, '/html/body//div/main//div/label//div/input', domainname)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//i')) > 0, "Billing Profile was not deleted")
        print("OK")
        filename = 0

    def test_login_page(self):
        global filename
        filename = "test_login_page.png"
        driver = self.driver
        driver.get(os.environ['CATALYST_SERVER'] + ":1443")
        driver.find_element_by_xpath('//*[@id="login_page_v1"]/div[3]/div/b/a').click()
        print("\nTry to login with no credentials...", end="")
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '//*[@id="q-app"]/div//main/div/form//button[contains(., "Sign In")]')))
        click_js(driver, '//*[@id="q-app"]/div//main/div/form//button[contains(., "Sign In")]')
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div[contains(., "Wrong credentials")]')) > 0, "Credentials werent rejected")
        print("OK")
        print("Try to login with false credentials...", end="")
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '//*[@aria-label="Username"]')))
        fill_element(driver, '//*[@aria-label="Username"]', 'invalid')
        fill_element(driver, '//*[@aria-label="Password"]', 'data')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main/div/form//button[contains(., "Sign In")]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div[contains(., "Wrong credentials")]')) > 0, "Credentials werent rejected")
        print("OK")
        print("Try to login with a wrong password...", end="")
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '//*[@aria-label="Username"]')))
        fill_element(driver, '//*[@aria-label="Username"]', 'administrator')
        fill_element(driver, '//*[@aria-label="Password"]', 'ubvakud')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main/div/form//button[contains(., "Sign In")]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div[contains(., "Wrong credentials")]')) > 0, "Credentials werent rejected")
        print("OK")
        print("Try to login with correct credentials...", end="")
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '//*[@aria-label="Username"]')))
        fill_element(driver, '//*[@aria-label="Username"]', 'administrator')
        fill_element(driver, '//*[@aria-label="Password"]', 'administrator')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main/div/form//button[contains(., "Sign In")]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div[contains(., "Dashboard")]')) > 0, "Credentials werent accepted")
        print("OK")
        """
        print("Try to open the handbook...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Documentation")]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Handbook")]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('/html/body/header/nav/div[1]/a[contains(., "The Sipwise NGCP Handbook")]')) > 0, "Handbook wasnt opened")
        print("OK")
        print("Try to navigate around the handbook...", end="")
        driver.find_element_by_xpath('/html/body//div//aside//div//nav/ul/li[contains(., "Architecture")]')
        self.assertTrue(
            len(driver.find_elements_by_xpath('/html/body//div//article/h1[contains(., "Architecture")]')) > 0, "Page 'Architecture' wasnt opened")
        """
        print("Try to logout...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]//div/button[@aria-label="UserMenu"]').click()
        driver.find_element_by_xpath('/html/body//div[@class="q-list"]/div[1]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="login-title"]')) > 0, "Logout wasnt successful")
        print("OK")
        filename = 0

    def test_reseller(self):
        global filename
        resellername = "reseller" + str(random.randint(1, 99999))
        resellercontract = "contract" + str(random.randint(1, 99999))
        filename = "test_reseller.png"
        driver = self.driver
        login_panel(driver)
        print("Go to 'Reseller'...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div/div[2]//div[contains(., "Settings")]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Resellers")]').click()
        print("OK")
        print("Try to create a new Reseller Contract...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/a[contains(., "Add")]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main/form//div/label//button[contains(., "Create")]').click()
        driver.find_element_by_xpath('/html/body//div[@class="q-list"]/a[2]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Contact")]/../div/input', "default")
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        wait_for_invisibility(driver, '/html/body//div[@class="q-virtual-scroll__content"]/div[1]')
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main/form//div//label[contains(., "Status")]').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main/form//div//label[contains(., "Billing Profile")]').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[1]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "External")]/../div/input', resellercontract)
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/button[contains(., "Save")]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('/html/body//div[@role="alert"][contains(., "Contract created successfully")]')) > 0, "Message 'Contract created successfully' didnt show up")
        print("OK")
        print("Try to create a new Reseller...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]//div/aside/div//a[contains(., "Resellers")]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/a[contains(., "Add")]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Contract")]/../div/input', resellercontract)
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body//div/div[@class="q-virtual-scroll__content"]/div[1]')))
        driver.find_element_by_xpath('/html/body//div/div[@class="q-virtual-scroll__content"]/div[1]').click()
        fill_element(driver, '//*[@id="q-app"]/div//main/form/div//label//div[contains(., "Name")]/../div/input',  resellername)
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main//div/button[contains(., "Save")]').click()
        print("OK")
        print("Check if reseller has been created...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', resellername)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//table/tbody/tr[1]/td[contains(., "' + resellername + '")]')) > 0, "Reseller was not found")
        print("OK")
        print("Try to rename reseller...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/table/tbody/tr[1]/td[4]/span').click()
        resellername = "reseller" + str(random.randint(1, 99999))
        fill_element(driver, '/html/body//div//label//div//input[@aria-label="Name"]', resellername)
        driver.find_element_by_xpath('/html/body//div/button[contains(., "Save")]').click()
        print("OK")
        print("Check if reseller name was changed...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', resellername)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//table/tbody/tr[1]/td[contains(., "' + resellername + '")]')) > 0, "Reseller name was not changed")
        print("OK")
        print("Try to edit reseller status...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[5]/span').click()
        driver.find_element_by_xpath('/html/body//div[contains(., "Locked")]').click()
        wait_for_invisibility(driver, '/html/body//div[@class="q-virtual-scroll__content"]')
        driver.find_element_by_xpath('/html/body//div/button[contains(., "Save")]').click()
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[5]/span[contains(., "Locked")]')) > 0, "Subscriber status was not edited")
        print("OK")
        print("Try to enable and disable WebRTC...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main//div/table/tbody/tr[1]/td[6]/div').click()
        driver.implicitly_wait(2)
        if len(driver.find_elements_by_xpath('/html/body//div[@role="alert"]//div[contains(., "Status code: 400")]')) == 0:
            self.assertTrue(
                len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div/table/tbody/tr[1]/td[6]/div[@aria-checked="true"]')) > 0, "WebRTC was not enabled")
            driver.find_element_by_xpath('//*[@id="q-app"]//div//main//div/table/tbody/tr[1]/td[6]/div').click()
            self.assertTrue(
                len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div/table/tbody/tr[1]/td[6]/div[@aria-checked="false"]')) > 0, "WebRTC was not disabled")
            print("OK")
        else:
            print("OK")
        driver.implicitly_wait(10)
        print("Try to open the reseller edit page...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[7]/button').click()
        WebDriverWait(driver, 10.).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/a[contains(., "Edit")]')))
        driver.find_element_by_xpath('/html/body//div/a[contains(., "Edit")]').click()
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div[@role="progressbar"]')
        print("OK")
        print("Try to edit reseller status...", end="")
        driver.find_element_by_xpath('//*[@id="q-app"]//div//main//form//div//label[@label="Status"]').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div//div[@class="q-virtual-scroll__content"]/div[2]')))
        time.sleep(1)
        driver.find_element_by_xpath('/html/body//div[@class="q-virtual-scroll__content"]/div[1]').click()
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div/button[contains(., "Save")]').click()
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div[@role="progressbar"]')
        click_js(driver, '//*[@id="q-app"]/div//main//div/button[contains(., "Close")]')
        print("OK")
        print("Check if reseller staus has been changed...", end="")
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        WebDriverWait(driver, 10).until(EC.element_to_be_clickable((By.XPATH, '/html/body//div/main//div/label//div/input')))
        fill_element(driver, '/html/body//div/main//div/label//div/input', resellername)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//table/tbody/tr[1]/td[contains(., "Active")]')) > 0, "Status was not changed")
        print("OK")
        print("Try to delete Reseller...", end="")
        wait_for_invisibility(driver, '//*[@id="q-app"]/div//main//div/table/thead/tr[2]/th/div[@role="progressbar"]')
        driver.find_element_by_xpath('//*[@id="q-app"]/div//main//div//table/tbody/tr[1]/td[7]/button').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div/div')))
        driver.find_element_by_xpath('/html/body/div[4]/div/div').click()
        WebDriverWait(driver, 10).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[4]/div[2]/div/div[3]/button[2]')))
        driver.find_element_by_xpath('/html/body/div[4]/div[2]/div/div[3]/button[2]').click()
        wait_for_invisibility(driver, '/html/body//div/main//div/label//div/input[contains(@class, "q-field--disabled")]')
        fill_element(driver, '/html/body//div/main//div/label//div/input', resellername)
        self.assertTrue(
            len(driver.find_elements_by_xpath('//*[@id="q-app"]//div//main//div//i')) > 0, "Reseller was not deleted")
        print("OK")
        filename = 0

    def tearDown(self):
        global filename
        driver = self.driver
        if filename:
            print("FAIL")
            driver.save_screenshot('/results/' + filename)
            filename = 0
        driver.quit()


if __name__ == '__main__':
    browser = os.environ['BROWSER']
    if browser == "all":
        print('----------------------------------------------------------------------')
        print('Running NGCP Panel tests now! (Browser: Firefox + Chrome)')
        print('----------------------------------------------------------------------')
        browser = "firefox"
        nose2.main(exit=False)
        browser = "chrome"
        nose2.main(exit=False)
    else:
        print('----------------------------------------------------------------------')
        print('Running NGCP Panel tests now! (Browser: ' + os.environ['BROWSER'].capitalize() + ')')
        print('----------------------------------------------------------------------')
        nose2.main(exit=False)
